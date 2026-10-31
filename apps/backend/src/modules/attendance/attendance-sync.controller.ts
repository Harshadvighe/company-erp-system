import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { BiometricDeviceService } from './biometric-device.service';
import {
  RegisterDeviceDto,
  UpdateDeviceDto,
  DeviceConnectionType,
  DeviceType,
} from './dto/register-device.dto';
import {
  SyncAttendanceRequestDto,
  SyncResponseDto,
} from './dto/sync-request.dto';

@ApiTags('Attendance - Biometric Punching Device Integration')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/attendance')
export class AttendanceController {