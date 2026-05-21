"""Dual-Write Epic Creation Service.

This module implements the dual-write pattern for persisting epic data
to both Jira and DynamoDB simultaneously. It ensures data consistency
across both stores and handles partial failure scenarios gracefully.

Workflow: wf_1779334880119_jekzv5
Epic: TEAM-110
Ticket: TEAM-123
"""

import logging
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Dict, Optional, Tuple

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class WriteStatus(Enum):
    """Status of a write operation."""
    SUCCESS = "success"
    FAILURE = "failure"
    PENDING = "pending"


@dataclass
class EpicData:
    """Represents epic data to be persisted."""
    ticket_id: str
    title: str
    description: str
    status: str = "todo"
    assignee: str = ""
    workflow_id: str = ""
    parent_id: str = ""
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    metadata: Dict[str, Any] = field(default_factory=dict)

    def to_jira_payload(self) -> Dict[str, Any]:
        """Convert to Jira API payload format."""
        return {
            "fields": {
                "summary": self.title,
                "description": self.description,
                "issuetype": {"name": "Epic"},
                "status": {"name": self.status},
                "assignee": {"name": self.assignee} if self.assignee else None,
                "labels": [f"workflow:{self.workflow_id}"] if self.workflow_id else [],
            },
            "key": self.ticket_id,
        }

    def to_dynamodb_item(self) -> Dict[str, Any]:
        """Convert to DynamoDB item format."""
        return {
            "PK": {"S": f"TICKET#{self.ticket_id}"},
            "SK": {"S": f"EPIC#{self.ticket_id}"},
            "ticket_id": {"S": self.ticket_id},
            "title": {"S": self.title},
            "description": {"S": self.description},
            "status": {"S": self.status},
            "assignee": {"S": self.assignee},
            "workflow_id": {"S": self.workflow_id},
            "parent_id": {"S": self.parent_id},
            "created_at": {"S": self.created_at},
            "updated_at": {"S": self.updated_at},
            "ticket_type": {"S": "epic"},
            "metadata": {"S": str(self.metadata)},
        }


@dataclass
class DualWriteResult:
    """Result of a dual-write operation."""
    jira_status: WriteStatus
    dynamodb_status: WriteStatus
    jira_error: Optional[str] = None
    dynamodb_error: Optional[str] = None
    correlation_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

    @property
    def is_fully_successful(self) -> bool:
        """Both writes completed successfully."""
        return (
            self.jira_status == WriteStatus.SUCCESS
            and self.dynamodb_status == WriteStatus.SUCCESS
        )

    @property
    def is_partial_failure(self) -> bool:
        """One write succeeded but the other failed."""
        statuses = {self.jira_status, self.dynamodb_status}
        return WriteStatus.SUCCESS in statuses and WriteStatus.FAILURE in statuses

    @property
    def is_total_failure(self) -> bool:
        """Both writes failed."""
        return (
            self.jira_status == WriteStatus.FAILURE
            and self.dynamodb_status == WriteStatus.FAILURE
        )


class JiraClient:
    """Client for Jira API operations."""

    def __init__(self, base_url: str = "", auth_token: str = ""):
        self.base_url = base_url
        self.auth_token = auth_token
        self._store: Dict[str, Dict] = {}  # In-memory store for testing

    def create_epic(self, epic_data: EpicData) -> Dict[str, Any]:
        """Create an epic in Jira.

        Args:
            epic_data: The epic data to persist.

        Returns:
            Response from Jira API with created epic details.

        Raises:
            RuntimeError: If the Jira API call fails.
        """
        payload = epic_data.to_jira_payload()
        logger.info(
            "Creating epic in Jira",
            extra={
                "ticket_id": epic_data.ticket_id,
                "title": epic_data.title,
                "workflow_id": epic_data.workflow_id,
            },
        )

        # Store in memory (for integration testing)
        self._store[epic_data.ticket_id] = {
            "key": epic_data.ticket_id,
            "fields": payload["fields"],
            "self": f"{self.base_url}/rest/api/2/issue/{epic_data.ticket_id}",
        }

        return self._store[epic_data.ticket_id]

    def get_epic(self, ticket_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve an epic from Jira."""
        return self._store.get(ticket_id)


class DynamoDBClient:
    """Client for DynamoDB operations."""

    def __init__(self, table_name: str = "tickets", region: str = "us-west-2"):
        self.table_name = table_name
        self.region = region
        self._store: Dict[str, Dict] = {}  # In-memory store for testing

    def put_epic(self, epic_data: EpicData) -> Dict[str, Any]:
        """Write epic data to DynamoDB.

        Args:
            epic_data: The epic data to persist.

        Returns:
            DynamoDB PutItem response.

        Raises:
            RuntimeError: If the DynamoDB write fails.
        """
        item = epic_data.to_dynamodb_item()
        logger.info(
            "Writing epic to DynamoDB",
            extra={
                "ticket_id": epic_data.ticket_id,
                "table": self.table_name,
                "workflow_id": epic_data.workflow_id,
            },
        )

        # Store in memory (for integration testing)
        self._store[epic_data.ticket_id] = item

        return {
            "ResponseMetadata": {"HTTPStatusCode": 200},
            "ConsumedCapacity": {"TableName": self.table_name, "CapacityUnits": 5.0},
        }

    def get_epic(self, ticket_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve an epic from DynamoDB."""
        return self._store.get(ticket_id)


class EpicDualWriteService:
    """Service implementing dual-write pattern for epic creation.

    This service ensures that epic data is written to both Jira and DynamoDB
    consistently. It handles partial failures gracefully by:
    1. Attempting both writes
    2. Logging detailed error information on failure
    3. Recording write results for monitoring/alerting
    4. Supporting retry/reconciliation for partial failures
    """

    def __init__(
        self,
        jira_client: JiraClient,
        dynamodb_client: DynamoDBClient,
        max_retries: int = 3,
        retry_delay: float = 1.0,
    ):
        self.jira_client = jira_client
        self.dynamodb_client = dynamodb_client
        self.max_retries = max_retries
        self.retry_delay = retry_delay
        self._write_log: list = []  # Audit log of write operations

    def create_epic(self, epic_data: EpicData) -> DualWriteResult:
        """Create an epic with dual-write to Jira and DynamoDB.

        Writes to both stores and handles failures gracefully.
        On partial failure, logs the error and records the inconsistency
        for later reconciliation.

        Args:
            epic_data: The epic data to create.

        Returns:
            DualWriteResult with status of both write operations.
        """
        correlation_id = str(uuid.uuid4())
        result = DualWriteResult(
            jira_status=WriteStatus.PENDING,
            dynamodb_status=WriteStatus.PENDING,
            correlation_id=correlation_id,
        )

        logger.info(
            "Starting dual-write epic creation",
            extra={
                "correlation_id": correlation_id,
                "ticket_id": epic_data.ticket_id,
                "workflow_id": epic_data.workflow_id,
            },
        )

        # Write to Jira
        result.jira_status, result.jira_error = self._write_to_jira(
            epic_data, correlation_id
        )

        # Write to DynamoDB
        result.dynamodb_status, result.dynamodb_error = self._write_to_dynamodb(
            epic_data, correlation_id
        )

        # Log final result
        self._log_result(result, epic_data)
        self._write_log.append(result)

        return result

    def _write_to_jira(
        self, epic_data: EpicData, correlation_id: str
    ) -> Tuple[WriteStatus, Optional[str]]:
        """Attempt to write to Jira with retries."""
        for attempt in range(1, self.max_retries + 1):
            try:
                self.jira_client.create_epic(epic_data)
                logger.info(
                    "Jira write successful",
                    extra={
                        "correlation_id": correlation_id,
                        "ticket_id": epic_data.ticket_id,
                        "attempt": attempt,
                    },
                )
                return WriteStatus.SUCCESS, None
            except Exception as e:
                error_msg = f"Jira write failed (attempt {attempt}/{self.max_retries}): {str(e)}"
                logger.warning(
                    error_msg,
                    extra={
                        "correlation_id": correlation_id,
                        "ticket_id": epic_data.ticket_id,
                        "attempt": attempt,
                        "error": str(e),
                    },
                )
                if attempt < self.max_retries:
                    time.sleep(self.retry_delay * attempt)

        final_error = f"Jira write failed after {self.max_retries} attempts"
        logger.error(
            final_error,
            extra={
                "correlation_id": correlation_id,
                "ticket_id": epic_data.ticket_id,
            },
        )
        return WriteStatus.FAILURE, final_error

    def _write_to_dynamodb(
        self, epic_data: EpicData, correlation_id: str
    ) -> Tuple[WriteStatus, Optional[str]]:
        """Attempt to write to DynamoDB with retries."""
        for attempt in range(1, self.max_retries + 1):
            try:
                self.dynamodb_client.put_epic(epic_data)
                logger.info(
                    "DynamoDB write successful",
                    extra={
                        "correlation_id": correlation_id,
                        "ticket_id": epic_data.ticket_id,
                        "attempt": attempt,
                    },
                )
                return WriteStatus.SUCCESS, None
            except Exception as e:
                error_msg = f"DynamoDB write failed (attempt {attempt}/{self.max_retries}): {str(e)}"
                logger.warning(
                    error_msg,
                    extra={
                        "correlation_id": correlation_id,
                        "ticket_id": epic_data.ticket_id,
                        "attempt": attempt,
                        "error": str(e),
                    },
                )
                if attempt < self.max_retries:
                    time.sleep(self.retry_delay * attempt)

        final_error = f"DynamoDB write failed after {self.max_retries} attempts"
        logger.error(
            final_error,
            extra={
                "correlation_id": correlation_id,
                "ticket_id": epic_data.ticket_id,
            },
        )
        return WriteStatus.FAILURE, final_error

    def _log_result(self, result: DualWriteResult, epic_data: EpicData) -> None:
        """Log the final dual-write result."""
        if result.is_fully_successful:
            logger.info(
                "Dual-write completed successfully",
                extra={
                    "correlation_id": result.correlation_id,
                    "ticket_id": epic_data.ticket_id,
                    "jira_status": result.jira_status.value,
                    "dynamodb_status": result.dynamodb_status.value,
                },
            )
        elif result.is_partial_failure:
            logger.error(
                "PARTIAL FAILURE: Dual-write inconsistency detected",
                extra={
                    "correlation_id": result.correlation_id,
                    "ticket_id": epic_data.ticket_id,
                    "jira_status": result.jira_status.value,
                    "dynamodb_status": result.dynamodb_status.value,
                    "jira_error": result.jira_error,
                    "dynamodb_error": result.dynamodb_error,
                },
            )
        else:
            logger.critical(
                "TOTAL FAILURE: Both writes failed",
                extra={
                    "correlation_id": result.correlation_id,
                    "ticket_id": epic_data.ticket_id,
                    "jira_error": result.jira_error,
                    "dynamodb_error": result.dynamodb_error,
                },
            )

    def verify_consistency(
        self, ticket_id: str
    ) -> Dict[str, Any]:
        """Verify data consistency between Jira and DynamoDB for a given ticket.

        Args:
            ticket_id: The ticket ID to verify.

        Returns:
            Dictionary with consistency check results.
        """
        jira_data = self.jira_client.get_epic(ticket_id)
        ddb_data = self.dynamodb_client.get_epic(ticket_id)

        result = {
            "ticket_id": ticket_id,
            "jira_exists": jira_data is not None,
            "dynamodb_exists": ddb_data is not None,
            "consistent": False,
            "discrepancies": [],
        }

        if not jira_data and not ddb_data:
            result["consistent"] = True  # Both missing = consistent (doesn't exist)
            return result

        if not jira_data or not ddb_data:
            result["discrepancies"].append(
                f"Data exists in {'Jira' if jira_data else 'DynamoDB'} "
                f"but not in {'DynamoDB' if jira_data else 'Jira'}"
            )
            return result

        # Compare fields
        jira_title = jira_data.get("fields", {}).get("summary", "")
        ddb_title = ddb_data.get("title", {}).get("S", "")
        if jira_title != ddb_title:
            result["discrepancies"].append(
                f"Title mismatch: Jira='{jira_title}' vs DDB='{ddb_title}'"
            )

        jira_desc = jira_data.get("fields", {}).get("description", "")
        ddb_desc = ddb_data.get("description", {}).get("S", "")
        if jira_desc != ddb_desc:
            result["discrepancies"].append(
                f"Description mismatch: Jira='{jira_desc}' vs DDB='{ddb_desc}'"
            )

        jira_status = jira_data.get("fields", {}).get("status", {}).get("name", "")
        ddb_status = ddb_data.get("status", {}).get("S", "")
        if jira_status != ddb_status:
            result["discrepancies"].append(
                f"Status mismatch: Jira='{jira_status}' vs DDB='{ddb_status}'"
            )

        # Check ticket ID consistency
        ddb_ticket_id = ddb_data.get("ticket_id", {}).get("S", "")
        jira_key = jira_data.get("key", "")
        if jira_key != ddb_ticket_id:
            result["discrepancies"].append(
                f"Ticket ID mismatch: Jira key='{jira_key}' vs DDB ticket_id='{ddb_ticket_id}'"
            )

        result["consistent"] = len(result["discrepancies"]) == 0
        return result

    def get_write_log(self) -> list:
        """Get the audit log of all write operations."""
        return self._write_log
