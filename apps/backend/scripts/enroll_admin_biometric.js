require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { FaceRecognitionService } = require('../dist/src/core/biometrics/face-recognition.service');

const prisma = new PrismaClient();
const faceService = new FaceRecognitionService(prisma);

function createTestJpegImage(seedByte) {
  const header = Buffer.from([
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00,
  ]);
  const body = Buffer.alloc(2048);
  for (let i = 0; i < 2048; i++) {
    body[i] = ((i * 7) ^ seedByte) % 256;
  }
  const trailer = Buffer.from([0xff, 0xd9]);
  return `data:image/jpeg;base64,${Buffer.concat([header, body, trailer]).toString('base64')}`;
}

async function enrollAdmin() {
  const admin = await prisma.user.findFirst({
    where: { username: 'admin' },
    include: { faceBiometric: true }
  });

  if (!admin) {
    console.error('Admin user not found!');
    return;
  }

  // 1. Extract biometric vector from registered test seed 0x5a
  const photo = createTestJpegImage(0x5a);
  const extraction = await faceService.validateAndExtractFace(photo);
  console.log('Extracted 128d descriptor with confidence:', extraction.confidence);

  // 2. Encrypt descriptor with AES-256-GCM
  const encrypted = faceService.encryptEmbedding(extraction.descriptor);

  // 3. Upsert into EmployeeFaceBiometric
  if (admin.faceBiometric) {
    await prisma.employeeFaceBiometric.update({
      where: { id: admin.faceBiometric.id },
      data: {
        encryptedEmbedding: encrypted.encryptedEmbedding,
        embeddingIv: encrypted.embeddingIv,
        embeddingAuthTag: encrypted.embeddingAuthTag,
        isActive: true,
        updatedAt: new Date(),
      }
    });
  } else {
    await prisma.employeeFaceBiometric.create({
      data: {
        userId: admin.id,
        encryptedEmbedding: encrypted.encryptedEmbedding,
        embeddingIv: encrypted.embeddingIv,
        embeddingAuthTag: encrypted.embeddingAuthTag,
        embeddingVersion: 'v1.0',
        faceModel: 'ssd-mobilenetv1-128d',
        isActive: true,
      }
    });
  }

  // 4. Update admin user status
  await prisma.user.update({
    where: { id: admin.id },
    data: {
      faceVerificationEnabled: true,
      faceVerificationStatus: 'ENROLLED',
      failedFaceAttempts: 0,
      faceLockoutUntil: null,
      faceEnrolledAt: new Date(),
    }
  });

  console.log('Successfully enrolled admin user with AES-256-GCM encrypted facial biometric!');
}

enrollAdmin().catch(console.error).finally(() => prisma.$disconnect());
