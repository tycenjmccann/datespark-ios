import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock AWS SDK modules
const mockGetSignedUrl = vi.fn();
const mockPutObjectCommand = vi.fn();

vi.mock('@aws-sdk/client-s3', () => ({
  S3Client: vi.fn().mockImplementation(() => ({})),
  PutObjectCommand: vi.fn().mockImplementation((input) => {
    mockPutObjectCommand(input);
    return { input };
  }),
}));

vi.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: mockGetSignedUrl,
}));

// Must import after mocks are set up
import {
  generatePresignedUploadUrl,
  getProfilePhotoKey,
  MAX_CONTENT_LENGTH,
  PRESIGN_EXPIRATION_SECONDS,
  ALLOWED_CONTENT_TYPE,
} from '../s3-profile';

describe('s3-profile', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    process.env.S3_BUCKET_NAME = 'test-profile-photos-bucket';
    process.env.AWS_REGION = 'us-east-1';
    mockGetSignedUrl.mockResolvedValue('https://s3.amazonaws.com/presigned-url');
  });

  describe('constants', () => {
    it('MAX_CONTENT_LENGTH should be 10MB (10485760 bytes)', () => {
      expect(MAX_CONTENT_LENGTH).toBe(10 * 1024 * 1024);
      expect(MAX_CONTENT_LENGTH).toBe(10485760);
    });

    it('PRESIGN_EXPIRATION_SECONDS should be 300 (5 minutes)', () => {
      expect(PRESIGN_EXPIRATION_SECONDS).toBe(300);
    });

    it('ALLOWED_CONTENT_TYPE should be image/webp', () => {
      expect(ALLOWED_CONTENT_TYPE).toBe('image/webp');
    });
  });

  describe('getProfilePhotoKey', () => {
    it('should generate correct S3 key for user', () => {
      expect(getProfilePhotoKey('user-123')).toBe('profiles/user-123/avatar.webp');
    });

    it('should handle various userId formats', () => {
      expect(getProfilePhotoKey('abc-def-ghi')).toBe('profiles/abc-def-ghi/avatar.webp');
      expect(getProfilePhotoKey('12345')).toBe('profiles/12345/avatar.webp');
    });
  });

  describe('generatePresignedUploadUrl', () => {
    it('should NOT include ContentLength in PutObjectCommand (TEAM-62 fix)', async () => {
      await generatePresignedUploadUrl('user-123');

      // This is the critical assertion — ContentLength must NOT be present
      const commandInput = mockPutObjectCommand.mock.calls[0][0];
      expect(commandInput).not.toHaveProperty('ContentLength');
    });

    it('should set ContentType to image/webp', async () => {
      await generatePresignedUploadUrl('user-123');

      const commandInput = mockPutObjectCommand.mock.calls[0][0];
      expect(commandInput.ContentType).toBe('image/webp');
    });

    it('should use correct bucket from environment variable', async () => {
      await generatePresignedUploadUrl('user-123');

      const commandInput = mockPutObjectCommand.mock.calls[0][0];
      expect(commandInput.Bucket).toBe('test-profile-photos-bucket');
    });

    it('should generate correct S3 object key', async () => {
      await generatePresignedUploadUrl('user-456');

      const commandInput = mockPutObjectCommand.mock.calls[0][0];
      expect(commandInput.Key).toBe('profiles/user-456/avatar.webp');
    });

    it('should set presigned URL expiration to 300 seconds', async () => {
      await generatePresignedUploadUrl('user-123');

      expect(mockGetSignedUrl).toHaveBeenCalledWith(
        expect.anything(),
        expect.anything(),
        { expiresIn: 300 }
      );
    });

    it('should return url and objectKey', async () => {
      const result = await generatePresignedUploadUrl('user-789');

      expect(result).toEqual({
        url: 'https://s3.amazonaws.com/presigned-url',
        objectKey: 'profiles/user-789/avatar.webp',
      });
    });

    it('should throw if S3_BUCKET_NAME is not set', async () => {
      delete process.env.S3_BUCKET_NAME;

      await expect(generatePresignedUploadUrl('user-123')).rejects.toThrow(
        'S3_BUCKET_NAME environment variable is not configured'
      );
    });

    it('should throw if userId is empty', async () => {
      await expect(generatePresignedUploadUrl('')).rejects.toThrow(
        'userId is required to generate presigned URL'
      );
    });
  });
});
