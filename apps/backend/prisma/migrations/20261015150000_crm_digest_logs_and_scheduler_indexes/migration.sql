-- CreateTable
CREATE TABLE "crm_digest_logs" (
    "id" TEXT NOT NULL,
    "digestDate" TEXT NOT NULL,
    "staffId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "activityCount" INTEGER NOT NULL DEFAULT 0,
    "dispatchedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "crm_digest_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "crm_digest_logs_digestDate_staffId_key" ON "crm_digest_logs"("digestDate", "staffId");

-- CreateIndex
CREATE INDEX "crm_digest_logs_digestDate_idx" ON "crm_digest_logs"("digestDate");

-- CreateIndex
CREATE INDEX "crm_digest_logs_userId_idx" ON "crm_digest_logs"("userId");

-- CreateIndex on crm_follow_ups
CREATE INDEX IF NOT EXISTS "crm_follow_ups_reminderSentAt_idx" ON "crm_follow_ups"("reminderSentAt");
CREATE INDEX IF NOT EXISTS "crm_follow_ups_escalatedAt_idx" ON "crm_follow_ups"("escalatedAt");
