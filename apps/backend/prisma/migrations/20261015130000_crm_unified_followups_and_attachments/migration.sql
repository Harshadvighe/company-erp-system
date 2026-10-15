-- AlterTable crm_activities: Add customerRequirements, productsDiscussed, documentsSent
ALTER TABLE "crm_activities" ADD COLUMN IF NOT EXISTS "customerRequirements" TEXT;
ALTER TABLE "crm_activities" ADD COLUMN IF NOT EXISTS "productsDiscussed" TEXT;
ALTER TABLE "crm_activities" ADD COLUMN IF NOT EXISTS "documentsSent" TEXT;

-- AlterTable crm_follow_ups: Add completedActivityId, parentFollowUpId, idempotencyKey, reminderSentAt, escalatedAt, escalatedToStaffId
ALTER TABLE "crm_follow_ups" ADD COLUMN IF NOT EXISTS "completedActivityId" TEXT;
ALTER TABLE "crm_follow_ups" ADD COLUMN IF NOT EXISTS "parentFollowUpId" TEXT;
ALTER TABLE "crm_follow_ups" ADD COLUMN IF NOT EXISTS "idempotencyKey" TEXT;
ALTER TABLE "crm_follow_ups" ADD COLUMN IF NOT EXISTS "reminderSentAt" TIMESTAMP(3);
ALTER TABLE "crm_follow_ups" ADD COLUMN IF NOT EXISTS "escalatedAt" TIMESTAMP(3);
ALTER TABLE "crm_follow_ups" ADD COLUMN IF NOT EXISTS "escalatedToStaffId" TEXT;

-- CreateTable crm_attachments
CREATE TABLE IF NOT EXISTS "crm_attachments" (
    "id" TEXT NOT NULL,
    "customerId" TEXT,
    "followUpId" TEXT,
    "activityId" TEXT,
    "fileName" TEXT NOT NULL,
    "storagePath" TEXT NOT NULL,
    "fileUrl" TEXT,
    "mimeType" TEXT,
    "fileSizeBytes" INTEGER NOT NULL DEFAULT 0,
    "mediaClass" TEXT NOT NULL DEFAULT 'DOCUMENT',
    "sourceCategory" TEXT,
    "description" TEXT,
    "uploadedById" TEXT,
    "uploadedByName" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "crm_attachments_pkey" PRIMARY KEY ("id")
);

-- Unique and index constraints for crm_follow_ups
CREATE UNIQUE INDEX IF NOT EXISTS "crm_follow_ups_completedActivityId_key" ON "crm_follow_ups"("completedActivityId");
CREATE UNIQUE INDEX IF NOT EXISTS "crm_follow_ups_idempotencyKey_key" ON "crm_follow_ups"("idempotencyKey");
CREATE INDEX IF NOT EXISTS "crm_follow_ups_parentFollowUpId_idx" ON "crm_follow_ups"("parentFollowUpId");

-- Indexes for crm_attachments
CREATE INDEX IF NOT EXISTS "crm_attachments_customerId_idx" ON "crm_attachments"("customerId");
CREATE INDEX IF NOT EXISTS "crm_attachments_followUpId_idx" ON "crm_attachments"("followUpId");
CREATE INDEX IF NOT EXISTS "crm_attachments_activityId_idx" ON "crm_attachments"("activityId");
CREATE INDEX IF NOT EXISTS "crm_attachments_uploadedById_idx" ON "crm_attachments"("uploadedById");
CREATE INDEX IF NOT EXISTS "crm_attachments_mediaClass_idx" ON "crm_attachments"("mediaClass");

-- Foreign key constraints
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'crm_follow_ups_completedActivityId_fkey'
    ) THEN
        ALTER TABLE "crm_follow_ups" ADD CONSTRAINT "crm_follow_ups_completedActivityId_fkey" 
        FOREIGN KEY ("completedActivityId") REFERENCES "crm_activities"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'crm_follow_ups_parentFollowUpId_fkey'
    ) THEN
        ALTER TABLE "crm_follow_ups" ADD CONSTRAINT "crm_follow_ups_parentFollowUpId_fkey" 
        FOREIGN KEY ("parentFollowUpId") REFERENCES "crm_follow_ups"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'crm_attachments_customerId_fkey'
    ) THEN
        ALTER TABLE "crm_attachments" ADD CONSTRAINT "crm_attachments_customerId_fkey" 
        FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'crm_attachments_followUpId_fkey'
    ) THEN
        ALTER TABLE "crm_attachments" ADD CONSTRAINT "crm_attachments_followUpId_fkey" 
        FOREIGN KEY ("followUpId") REFERENCES "crm_follow_ups"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'crm_attachments_activityId_fkey'
    ) THEN
        ALTER TABLE "crm_attachments" ADD CONSTRAINT "crm_attachments_activityId_fkey" 
        FOREIGN KEY ("activityId") REFERENCES "crm_activities"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'crm_attachments_uploadedById_fkey'
    ) THEN
        ALTER TABLE "crm_attachments" ADD CONSTRAINT "crm_attachments_uploadedById_fkey" 
        FOREIGN KEY ("uploadedById") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
END $$;
