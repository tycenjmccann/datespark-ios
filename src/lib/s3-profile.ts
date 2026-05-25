import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

/**
 * Maximum content length for profile photo uploads (10MB).
 * Used for API-level validation before generating presigned URLs.
 * Matches the frontend MAX_FILE_SIZE validation.
 */
export const MAX_CONTENT_LENGTH = 10 * 1024 * 1024; // 10MB = 10485760 bytes

/**
 * Presigned URL expiration time in seconds (5 minutes).
 */
export const PRESIGN_EXPIRATION_SECONDS = 300;

/**
 * Allowed content type for profile photo uploads.
 */
export const ALLOWED_CONTENT_TYPE = 'image/webp';

const s3Client = new S3Client({
  region: process.env.AWS_REGION || 'us-east-1',
});

/**
 * Generates the S3 object key for a user's profile avatar.
 */
export function getProfilePhotoKey(userId: string): string {
  return `profiles/${userId}/avatar.webp`;
}

export interface PresignedUploadResult {
  url: string;
  objectKey: string;
}

/**
 * Generates a presigned PUT URL for uploading a profile photo to S3.
 *
 * NOTE: ContentLength is intentionally NOT set on the PutObjectCommand.
 * Setting ContentLength creates a presigned URL that requires the upload
 * to be EXACTLY that size, which fails for cropped/resized images.
 *
 * Size enforcement is handled at the API route level (validating the
 * request before issuing the presigned URL) and via S3 bucket policy.
 *
 * @param userId - The authenticated user's ID
 * @returns Presigned URL and the S3 object key
 */
export async function generatePresignedUploadUrl(
  userId: string
): Promise<PresignedUploadResult> {
  const bucketName = process.env.S3_BUCKET_NAME;

  if (!bucketName) {
    throw new Error('S3_BUCKET_NAME environment variable is not configured');
  }

  if (!userId) {
    throw new Error('userId is required to generate presigned URL');
  }

  const objectKey = getProfilePhotoKey(userId);

  const command = new PutObjectCommand({
    Bucket: bucketName,
    Key: objectKey,
    ContentType: ALLOWED_CONTENT_TYPE,
    // NOTE: ContentLength is intentionally omitted.
    // Previously this was set to 5242880 (5MB) which caused presigned URLs
    // to reject any upload that wasn't exactly 5MB.
    // See: TEAM-62
  });

  const url = await getSignedUrl(s3Client, command, {
    expiresIn: PRESIGN_EXPIRATION_SECONDS,
  });

  return { url, objectKey };
}
