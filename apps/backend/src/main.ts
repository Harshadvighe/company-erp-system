import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import * as dotenv from 'dotenv';

dotenv.config();

async function bootstrap() {
  const logger = new Logger('SaarkERPBackend');
  const app = await NestFactory.create(AppModule);

  // Enable CORS for Flutter Web & Mobile
  app.enableCors({
    origin: true,
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  // Global Validation Pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
    }),
  );

  // Global API Response Transform Interceptor
  app.useGlobalInterceptors(new TransformInterceptor());

  // Swagger OpenAPI Documentation Configuration
  const config = new DocumentBuilder()
    .setTitle('Saark Exploration ERP API Specifications')
    .setDescription('Integrated ERP Platform Backend for Saark Exploration Private Limited')
    .setVersion('1.0.0')
    .addBearerAuth()
    .build();
    
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  // Serve Flutter Web frontend directly through NestJS (at root / and all non-API paths)
  const express = require('express');
  const path = require('path');
  const fs = require('fs');

  const webCandidates = [
    path.resolve(process.cwd(), '../mobile/build/web'),
    path.resolve(process.cwd(), 'apps/mobile/build/web'),
    path.resolve(__dirname, '../../../../apps/mobile/build/web'),
    'd:/saark/New folder (2)/apps/mobile/build/web',
  ];
  const webDir = webCandidates.find((dir) => fs.existsSync(dir));

  if (webDir) {
    logger.log(`📱 Serving Flutter Web frontend from: ${webDir}`);
    app.use(express.static(webDir));

    // Client-side SPA routing fallback for Flutter Web
    app.use((req: any, res: any, next: any) => {
      if (req.method === 'GET' && !req.path.startsWith('/api') && !req.path.startsWith('/swagger')) {
        const indexPath = path.join(webDir, 'index.html');
        if (fs.existsSync(indexPath)) {
          return res.sendFile(indexPath);
        }
      }
      next();
    });
  }

  const port = process.env.PORT || 3000;
  await app.listen(port, '0.0.0.0');

  logger.log(`🚀 Saark Exploration ERP Backend active on port http://localhost:${port} and LAN http://0.0.0.0:${port}`);
  logger.log(`📖 OpenAPI Swagger Documentation available at http://localhost:${port}/api/docs`);
}

bootstrap();
