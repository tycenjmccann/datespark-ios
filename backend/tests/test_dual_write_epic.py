"""Integration tests for dual-write epic creation.

Validates that the dual-write mechanism correctly persists epic data
to both Jira and DynamoDB, with proper error handling for failure scenarios.

Workflow: wf_1779334880119_jekzv5
Epic: TEAM-110
Ticket: TEAM-123
"""

import logging
import unittest
from unittest.mock import MagicMock, patch

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from services.epic_dual_write_service import (
    DualWriteResult,
    DynamoDBClient,
    EpicData,
    EpicDualWriteService,
    JiraClient,
    WriteStatus,
)


class TestEpicDualWriteIntegration(unittest.TestCase):
    """Integration tests for dual-write epic creation to Jira and DynamoDB."""

    def setUp(self):
        """Set up test fixtures."""
        self.jira_client = JiraClient(
            base_url="https://team-project.atlassian.net",
            auth_token="test-token",
        )
        self.dynamodb_client = DynamoDBClient(
            table_name="workflow-tickets",
            region="us-west-2",
        )
        self.service = EpicDualWriteService(
            jira_client=self.jira_client,
            dynamodb_client=self.dynamodb_client,
            max_retries=3,
            retry_delay=0.01,  # Fast retries for testing
        )

    def _create_test_epic(self, ticket_id: str = "TEAM-110") -> EpicData:
        """Create a test epic matching TEAM-110."""
        return EpicData(
            ticket_id=ticket_id,
            title="DateSpark iOS App Development",
            description="Epic for the DateSpark iOS application development workflow",
            status="todo",
            workflow_id="wf_1779334880119_jekzv5",
            parent_id="",
            metadata={"source": "workflow_system", "version": "1.0"},
        )

    # =========================================================================
    # SUCCESS SCENARIOS
    # =========================================================================

    def test_epic_created_in_both_stores(self):
        """Verify epic is created in both Jira and DynamoDB successfully.

        Acceptance Criteria:
        - Epic created via workflow system is present in both Jira and DynamoDB
        """
        epic_data = self._create_test_epic()

        result = self.service.create_epic(epic_data)

        # Verify both writes succeeded
        self.assertEqual(result.jira_status, WriteStatus.SUCCESS)
        self.assertEqual(result.dynamodb_status, WriteStatus.SUCCESS)
        self.assertTrue(result.is_fully_successful)
        self.assertFalse(result.is_partial_failure)
        self.assertFalse(result.is_total_failure)

        # Verify data exists in both stores
        jira_epic = self.jira_client.get_epic("TEAM-110")
        ddb_epic = self.dynamodb_client.get_epic("TEAM-110")

        self.assertIsNotNone(jira_epic)
        self.assertIsNotNone(ddb_epic)

    def test_fields_consistent_across_stores(self):
        """Verify field consistency between Jira and DynamoDB.

        Acceptance Criteria:
        - Fields are consistent across both stores
        """
        epic_data = self._create_test_epic()
        self.service.create_epic(epic_data)

        # Use the consistency checker
        consistency = self.service.verify_consistency("TEAM-110")

        self.assertTrue(consistency["consistent"])
        self.assertTrue(consistency["jira_exists"])
        self.assertTrue(consistency["dynamodb_exists"])
        self.assertEqual(len(consistency["discrepancies"]), 0)

    def test_title_matches_across_stores(self):
        """Verify title field matches between Jira and DynamoDB."""
        epic_data = self._create_test_epic()
        self.service.create_epic(epic_data)

        jira_epic = self.jira_client.get_epic("TEAM-110")
        ddb_epic = self.dynamodb_client.get_epic("TEAM-110")

        jira_title = jira_epic["fields"]["summary"]
        ddb_title = ddb_epic["title"]["S"]

        self.assertEqual(jira_title, ddb_title)
        self.assertEqual(jira_title, "DateSpark iOS App Development")

    def test_description_matches_across_stores(self):
        """Verify description field matches between Jira and DynamoDB."""
        epic_data = self._create_test_epic()
        self.service.create_epic(epic_data)

        jira_epic = self.jira_client.get_epic("TEAM-110")
        ddb_epic = self.dynamodb_client.get_epic("TEAM-110")

        jira_desc = jira_epic["fields"]["description"]
        ddb_desc = ddb_epic["description"]["S"]

        self.assertEqual(jira_desc, ddb_desc)
        self.assertEqual(
            jira_desc,
            "Epic for the DateSpark iOS application development workflow",
        )

    def test_status_matches_across_stores(self):
        """Verify status field matches between Jira and DynamoDB."""
        epic_data = self._create_test_epic()
        self.service.create_epic(epic_data)

        jira_epic = self.jira_client.get_epic("TEAM-110")
        ddb_epic = self.dynamodb_client.get_epic("TEAM-110")

        jira_status = jira_epic["fields"]["status"]["name"]
        ddb_status = ddb_epic["status"]["S"]

        self.assertEqual(jira_status, ddb_status)
        self.assertEqual(jira_status, "todo")

    def test_ticket_id_matches_across_stores(self):
        """Verify ticket ID is consistent across both stores."""
        epic_data = self._create_test_epic()
        self.service.create_epic(epic_data)

        jira_epic = self.jira_client.get_epic("TEAM-110")
        ddb_epic = self.dynamodb_client.get_epic("TEAM-110")

        jira_key = jira_epic["key"]
        ddb_ticket_id = ddb_epic["ticket_id"]["S"]

        self.assertEqual(jira_key, ddb_ticket_id)
        self.assertEqual(jira_key, "TEAM-110")

    def test_workflow_id_persisted_in_dynamodb(self):
        """Verify workflow_id is persisted in DynamoDB."""
        epic_data = self._create_test_epic()
        self.service.create_epic(epic_data)

        ddb_epic = self.dynamodb_client.get_epic("TEAM-110")
        self.assertEqual(ddb_epic["workflow_id"]["S"], "wf_1779334880119_jekzv5")

    def test_correlation_id_generated(self):
        """Verify a unique correlation ID is generated for each write."""
        epic_data = self._create_test_epic()
        result = self.service.create_epic(epic_data)

        self.assertIsNotNone(result.correlation_id)
        self.assertTrue(len(result.correlation_id) > 0)

    # =========================================================================
    # ERROR SCENARIOS - JIRA FAILURE
    # =========================================================================

    def test_jira_write_failure_handled_gracefully(self):
        """Verify system handles Jira write failure gracefully.

        Acceptance Criteria:
        - Error scenarios are handled (Jira write failure)
        - No inconsistent state (DynamoDB should still succeed)
        """
        epic_data = self._create_test_epic()

        # Mock Jira client to fail
        self.jira_client.create_epic = MagicMock(
            side_effect=RuntimeError("Jira API connection timeout")
        )

        result = self.service.create_epic(epic_data)

        self.assertEqual(result.jira_status, WriteStatus.FAILURE)
        self.assertEqual(result.dynamodb_status, WriteStatus.SUCCESS)
        self.assertTrue(result.is_partial_failure)
        self.assertIn("failed after", result.jira_error)

    def test_jira_failure_still_writes_to_dynamodb(self):
        """Verify DynamoDB write proceeds even if Jira fails."""
        epic_data = self._create_test_epic()

        self.jira_client.create_epic = MagicMock(
            side_effect=RuntimeError("Jira unavailable")
        )

        self.service.create_epic(epic_data)

        # DynamoDB should still have the data
        ddb_epic = self.dynamodb_client.get_epic("TEAM-110")
        self.assertIsNotNone(ddb_epic)
        self.assertEqual(ddb_epic["ticket_id"]["S"], "TEAM-110")

    # =========================================================================
    # ERROR SCENARIOS - DYNAMODB FAILURE
    # =========================================================================

    def test_dynamodb_write_failure_handled_gracefully(self):
        """Verify system handles DynamoDB write failure gracefully.

        Acceptance Criteria:
        - Error scenarios are handled (DDB write failure)
        """
        epic_data = self._create_test_epic()

        # Mock DynamoDB client to fail
        self.dynamodb_client.put_epic = MagicMock(
            side_effect=RuntimeError("DynamoDB ProvisionedThroughputExceededException")
        )

        result = self.service.create_epic(epic_data)

        self.assertEqual(result.jira_status, WriteStatus.SUCCESS)
        self.assertEqual(result.dynamodb_status, WriteStatus.FAILURE)
        self.assertTrue(result.is_partial_failure)
        self.assertIn("failed after", result.dynamodb_error)

    def test_dynamodb_failure_still_writes_to_jira(self):
        """Verify Jira write completes even if DynamoDB fails."""
        epic_data = self._create_test_epic()

        self.dynamodb_client.put_epic = MagicMock(
            side_effect=RuntimeError("DynamoDB unavailable")
        )

        self.service.create_epic(epic_data)

        # Jira should still have the data
        jira_epic = self.jira_client.get_epic("TEAM-110")
        self.assertIsNotNone(jira_epic)
        self.assertEqual(jira_epic["key"], "TEAM-110")

    # =========================================================================
    # ERROR SCENARIOS - BOTH FAILURES
    # =========================================================================

    def test_both_writes_fail_handled_gracefully(self):
        """Verify system handles total failure (both writes fail)."""
        epic_data = self._create_test_epic()

        self.jira_client.create_epic = MagicMock(
            side_effect=RuntimeError("Jira unavailable")
        )
        self.dynamodb_client.put_epic = MagicMock(
            side_effect=RuntimeError("DynamoDB unavailable")
        )

        result = self.service.create_epic(epic_data)

        self.assertEqual(result.jira_status, WriteStatus.FAILURE)
        self.assertEqual(result.dynamodb_status, WriteStatus.FAILURE)
        self.assertTrue(result.is_total_failure)
        self.assertFalse(result.is_fully_successful)

    # =========================================================================
    # RETRY BEHAVIOR
    # =========================================================================

    def test_retries_on_transient_jira_failure(self):
        """Verify retry mechanism works for transient Jira failures."""
        epic_data = self._create_test_epic()

        # Fail twice, succeed on third attempt
        call_count = 0
        original_create = self.jira_client.create_epic

        def flaky_create(data):
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise RuntimeError("Temporary connection error")
            return original_create(data)

        self.jira_client.create_epic = flaky_create

        result = self.service.create_epic(epic_data)

        self.assertEqual(result.jira_status, WriteStatus.SUCCESS)
        self.assertEqual(call_count, 3)  # Failed twice, succeeded on third

    def test_retries_on_transient_dynamodb_failure(self):
        """Verify retry mechanism works for transient DynamoDB failures."""
        epic_data = self._create_test_epic()

        call_count = 0
        original_put = self.dynamodb_client.put_epic

        def flaky_put(data):
            nonlocal call_count
            call_count += 1
            if call_count < 2:
                raise RuntimeError("Temporary throughput exceeded")
            return original_put(data)

        self.dynamodb_client.put_epic = flaky_put

        result = self.service.create_epic(epic_data)

        self.assertEqual(result.dynamodb_status, WriteStatus.SUCCESS)
        self.assertEqual(call_count, 2)

    # =========================================================================
    # LOGGING VERIFICATION
    # =========================================================================

    def test_errors_logged_with_detail(self):
        """Verify errors are logged with sufficient detail for debugging.

        Acceptance Criteria:
        - Errors are logged with sufficient detail for debugging
        """
        epic_data = self._create_test_epic()

        self.jira_client.create_epic = MagicMock(
            side_effect=RuntimeError("Connection refused to jira.example.com:443")
        )

        with self.assertLogs(level=logging.WARNING) as log_context:
            result = self.service.create_epic(epic_data)

        # Verify log messages contain useful debugging info
        log_output = "\n".join(log_context.output)
        self.assertIn("Jira write failed", log_output)
        self.assertIn("TEAM-110", log_output)

    def test_successful_write_logged(self):
        """Verify successful dual-write is logged."""
        epic_data = self._create_test_epic()

        with self.assertLogs(level=logging.INFO) as log_context:
            self.service.create_epic(epic_data)

        log_output = "\n".join(log_context.output)
        self.assertIn("Jira write successful", log_output)
        self.assertIn("DynamoDB write successful", log_output)

    def test_partial_failure_logged_as_error(self):
        """Verify partial failures are logged at ERROR level."""
        epic_data = self._create_test_epic()

        self.dynamodb_client.put_epic = MagicMock(
            side_effect=RuntimeError("DynamoDB unavailable")
        )

        with self.assertLogs(level=logging.WARNING) as log_context:
            self.service.create_epic(epic_data)

        log_output = "\n".join(log_context.output)
        self.assertIn("PARTIAL FAILURE", log_output)

    # =========================================================================
    # AUDIT TRAIL
    # =========================================================================

    def test_write_log_tracks_operations(self):
        """Verify the write log tracks all dual-write operations."""
        epic1 = self._create_test_epic("TEAM-110")
        epic2 = self._create_test_epic("TEAM-111")

        self.service.create_epic(epic1)
        self.service.create_epic(epic2)

        write_log = self.service.get_write_log()
        self.assertEqual(len(write_log), 2)
        self.assertTrue(write_log[0].is_fully_successful)
        self.assertTrue(write_log[1].is_fully_successful)

    # =========================================================================
    # CONSISTENCY VERIFICATION
    # =========================================================================

    def test_verify_consistency_detects_missing_jira(self):
        """Verify consistency check detects missing Jira data."""
        # Only write to DynamoDB directly (bypassing dual-write)
        epic_data = self._create_test_epic()
        self.dynamodb_client.put_epic(epic_data)

        consistency = self.service.verify_consistency("TEAM-110")

        self.assertFalse(consistency["consistent"])
        self.assertFalse(consistency["jira_exists"])
        self.assertTrue(consistency["dynamodb_exists"])

    def test_verify_consistency_detects_missing_dynamodb(self):
        """Verify consistency check detects missing DynamoDB data."""
        # Only write to Jira directly (bypassing dual-write)
        epic_data = self._create_test_epic()
        self.jira_client.create_epic(epic_data)

        consistency = self.service.verify_consistency("TEAM-110")

        self.assertFalse(consistency["consistent"])
        self.assertTrue(consistency["jira_exists"])
        self.assertFalse(consistency["dynamodb_exists"])

    def test_verify_consistency_nonexistent_ticket(self):
        """Verify consistency check for a ticket that doesn't exist anywhere."""
        consistency = self.service.verify_consistency("TEAM-999")

        self.assertTrue(consistency["consistent"])  # Both missing = consistent
        self.assertFalse(consistency["jira_exists"])
        self.assertFalse(consistency["dynamodb_exists"])


class TestEpicDataModel(unittest.TestCase):
    """Tests for the EpicData model serialization."""

    def test_to_jira_payload(self):
        """Verify EpicData serializes correctly to Jira format."""
        epic = EpicData(
            ticket_id="TEAM-110",
            title="Test Epic",
            description="Test description",
            status="in_progress",
            workflow_id="wf_test",
        )

        payload = epic.to_jira_payload()

        self.assertEqual(payload["key"], "TEAM-110")
        self.assertEqual(payload["fields"]["summary"], "Test Epic")
        self.assertEqual(payload["fields"]["description"], "Test description")
        self.assertEqual(payload["fields"]["issuetype"]["name"], "Epic")
        self.assertIn("workflow:wf_test", payload["fields"]["labels"])

    def test_to_dynamodb_item(self):
        """Verify EpicData serializes correctly to DynamoDB format."""
        epic = EpicData(
            ticket_id="TEAM-110",
            title="Test Epic",
            description="Test description",
            status="todo",
            workflow_id="wf_test",
        )

        item = epic.to_dynamodb_item()

        self.assertEqual(item["PK"]["S"], "TICKET#TEAM-110")
        self.assertEqual(item["SK"]["S"], "EPIC#TEAM-110")
        self.assertEqual(item["ticket_id"]["S"], "TEAM-110")
        self.assertEqual(item["title"]["S"], "Test Epic")
        self.assertEqual(item["description"]["S"], "Test description")
        self.assertEqual(item["status"]["S"], "todo")
        self.assertEqual(item["workflow_id"]["S"], "wf_test")
        self.assertEqual(item["ticket_type"]["S"], "epic")


class TestDualWriteResult(unittest.TestCase):
    """Tests for the DualWriteResult model."""

    def test_fully_successful(self):
        result = DualWriteResult(
            jira_status=WriteStatus.SUCCESS,
            dynamodb_status=WriteStatus.SUCCESS,
        )
        self.assertTrue(result.is_fully_successful)
        self.assertFalse(result.is_partial_failure)
        self.assertFalse(result.is_total_failure)

    def test_partial_failure_jira(self):
        result = DualWriteResult(
            jira_status=WriteStatus.FAILURE,
            dynamodb_status=WriteStatus.SUCCESS,
            jira_error="Connection timeout",
        )
        self.assertFalse(result.is_fully_successful)
        self.assertTrue(result.is_partial_failure)
        self.assertFalse(result.is_total_failure)

    def test_partial_failure_dynamodb(self):
        result = DualWriteResult(
            jira_status=WriteStatus.SUCCESS,
            dynamodb_status=WriteStatus.FAILURE,
            dynamodb_error="Throughput exceeded",
        )
        self.assertFalse(result.is_fully_successful)
        self.assertTrue(result.is_partial_failure)
        self.assertFalse(result.is_total_failure)

    def test_total_failure(self):
        result = DualWriteResult(
            jira_status=WriteStatus.FAILURE,
            dynamodb_status=WriteStatus.FAILURE,
            jira_error="Jira down",
            dynamodb_error="DDB down",
        )
        self.assertFalse(result.is_fully_successful)
        self.assertFalse(result.is_partial_failure)
        self.assertTrue(result.is_total_failure)


if __name__ == "__main__":
    unittest.main()
