import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

export interface Response<T> {
  success: boolean;
  message: string;
  data: T;
  meta: any;
}

@Injectable()
export class TransformInterceptor<T> implements NestInterceptor<T, Response<T>> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<Response<T>> {
    const request = context.switchToHttp().getRequest();
    
    return next.handle().pipe(
      map((result) => {
        // If result already formatted with success key (e.g. paginated)
        if (result && typeof result === 'object' && 'success' in result) {
          return result;
        }

        let message = 'Operation completed successfully';
        let data = result;
        let meta: any = {
          timestamp: new Date().toISOString(),
          path: request.url,
        };

        if (result && typeof result === 'object' && 'data' in result && 'message' in result) {
          message = result.message;
          data = result.data;
          if (result.meta) {
            meta = { ...meta, ...result.meta };
          }
        }

        return {
          success: true,
          message,
          data,
          meta,
        };
      }),
    );
  }
}
