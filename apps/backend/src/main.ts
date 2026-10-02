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

  const port = process.env.PORT || 3000;
  await app.listen(port, '0.0.0.0');

  logger.log(`🚀 Saark Exploration ERP Backend active on port http://localhost:${port} and LAN http://0.0.0.0:${port}`);
  logger.log(`📖 OpenAPI Swagger Documentation available at http://localhost:${port}/api/docs`);
}

bootstrap();
