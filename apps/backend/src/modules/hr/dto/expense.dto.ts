import { IsString, IsNotEmpty, IsNumber, IsOptional, IsIn, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateExpenseDto {
  @ApiProperty({ description: 'Title or purpose of the expense', example: 'Site Visit Travel (Pune to Chakan)' })
  @IsString()
  @IsNotEmpty()
  title: string;

  @ApiProperty({
    description: 'Expense category',
    example: 'TRAVEL',
    enum: ['TRAVEL', 'STATIONERY', 'TEA_PANTRY', 'COURIER', 'TOOLS', 'UTILITIES', 'OTHER'],
  })
  @IsString()
  @IsNotEmpty()
  @IsIn(['TRAVEL', 'STATIONERY', 'TEA_PANTRY', 'COURIER', 'TOOLS', 'UTILITIES', 'OTHER'])
  category: string;

  @ApiProperty({ description: 'Total claimed amount in INR', example: 1450.0 })
  @IsNumber()
  @Min(1)
  amount: number;

  @ApiPropertyOptional({ description: 'Date when expense occurred', example: '2026-11-18' })
  @IsOptional()
  @IsString()
  expenseDate?: string;

  @ApiPropertyOptional({ description: 'Detailed justification / reason', example: 'Fuel and toll charges for customer panel inspection.' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ description: 'Photo or URL of bill / receipt receipt', example: 'data:image/jpeg;base64,...' })
  @IsOptional()
  @IsString()
  receiptUrl?: string;

  @ApiPropertyOptional({ description: 'Staff employee name', example: 'Rahul Yeole' })
  @IsOptional()
  @IsString()
  staffName?: string;

  @ApiPropertyOptional({ description: 'Department name', example: 'Sales & Marketing' })
  @IsOptional()
  @IsString()
  department?: string;
}

export class ReviewExpenseDto {
  @ApiProperty({ description: 'Review status by Department or HR Admin', example: 'REVIEWED', enum: ['REVIEWED', 'REJECTED'] })
  @IsString()
  @IsIn(['REVIEWED', 'REJECTED'])
  status: string;

  @ApiPropertyOptional({ description: 'Reviewer comments or verification notes', example: 'Verified against visitor register and original invoice.' })
  @IsOptional()
  @IsString()
  reviewNotes?: string;
}

export class ApproveExpenseDto {
  @ApiProperty({ description: 'Approval decision by Managing Director (Saarkadmin)', example: 'APPROVED', enum: ['APPROVED', 'REJECTED'] })
  @IsString()
  @IsIn(['APPROVED', 'REJECTED'])
  status: string;

  @ApiPropertyOptional({ description: 'Managing Director approval comments', example: 'Approved for immediate payment.' })
  @IsOptional()
  @IsString()
  approvalNotes?: string;

  @ApiPropertyOptional({ description: 'Reimbursement payment mode', example: 'PETTY_CASH', enum: ['PETTY_CASH', 'BANK_TRANSFER', 'UPI'] })
  @IsOptional()
  @IsString()
  paymentMode?: string;

  @ApiPropertyOptional({ description: 'Whether to immediately post as paid in ledger', example: true })
  @IsOptional()
  markPaid?: boolean;
}

