import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/features/hr/presentation/widgets/employee_profile_view.dart';
import 'package:saark_erp_mobile/features/hr/presentation/widgets/hr_sub_views.dart';

class _HrMenuItem {
  final String id;
  final String label;
  final IconData icon;
  final bool isIndented;

  const _HrMenuItem({
    required this.id,
    required this.label,
    required this.icon,
    this.isIndented = false,
  });
}

const _hrMenuItems = [
  _HrMenuItem(id: 'employee_profile', label: 'Employee Profile', icon: Icons.person),
  _HrMenuItem(id: 'employee_documents', label: 'Employee Documents', icon: Icons.description_outlined),
  _HrMenuItem(id: 'recruitment', label: 'Recruitment (ATS)', icon: Icons.person_search_outlined),
  _HrMenuItem(id: 'interviews', label: 'Interviews', icon: Icons.record_voice_over_outlined, isIndented: true),
  _HrMenuItem(id: 'shift_setup', label: 'Shift Setup', icon: Icons.alarm),
  _HrMenuItem(id: 'attendance_leave', label: 'Attendance & Leave', icon: Icons.calendar_month_outlined),
  _HrMenuItem(id: 'leave_types', label: 'Leave Types', icon: Icons.article_outlined),
  _HrMenuItem(id: 'leave_balances', label: 'Leave Balances', icon: Icons.balance_outlined),
  _HrMenuItem(id: 'leave_requests', label: 'Leave Requests', icon: Icons.move_to_inbox_outlined),
  _HrMenuItem(id: 'payroll_compensation', label: 'Payroll & Compensation', icon: Icons.payments_outlined),
  _HrMenuItem(id: 'payroll_runs', label: 'Payroll Runs', icon: Icons.credit_card_outlined),
  _HrMenuItem(id: 'performance_goals', label: 'Performance & Goals', icon: Icons.track_changes_outlined),
  _HrMenuItem(id: 'appraisals', label: 'Appraisals', icon: Icons.star),
  _HrMenuItem(id: 'learning_development', label: 'Learning & Development', icon: Icons.menu_book_outlined),
  _HrMenuItem(id: 'offboarding_separation', label: 'Offboarding & Separation', icon: Icons.meeting_room_outlined),
];

class HrDashboardPage extends ConsumerStatefulWidget {
  final int initialTab;
  const HrDashboardPage({super.key, this.initialTab = 0});

  @override
  ConsumerState<HrDashboardPage> createState() => _HrDashboardPageState();
}

class _HrDashboardPageState extends ConsumerState<HrDashboardPage> {
  late int _selectedMenuIndex;

  @override
  void initState() {
    super.initState();
    _selectedMenuIndex = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF141517),
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(isDrawer: true)),
      body: Column(
        children: [
          _buildHeader(showMenuButton: !isDesktop),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop) _buildSidebar(isDrawer: false),
                Expanded(
                  child: Container(
                    color: const Color(0xFF141517),
                    child: _buildActiveWorkspace(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SIDEBAR NAVIGATION (Matches screenshot exactly)
  // -------------------------------------------------------------
  Widget _buildSidebar({required bool isDrawer}) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2024),
        border: Border(right: BorderSide(color: Color(0xFF26282E))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header inside sidebar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1E2024),
              border: Border(bottom: BorderSide(color: Color(0xFF26282E))),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Human Resources',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Employee records, recruitment, attendance, payroll, performance, training, and separation.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white60,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Menu Items List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _hrMenuItems.length,
              itemBuilder: (context, index) {
                final item = _hrMenuItems[index];
                final isSelected = _selectedMenuIndex == index;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMenuIndex = index;
                    });
                    if (isDrawer) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.only(
                      left: item.isIndented ? 36 : 14,
                      right: 14,
                      top: 11,
                      bottom: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF26522) : Colors.transparent,
                      border: const Border(
                        bottom: BorderSide(color: Color(0xFF26282E), width: 1.0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 16,
                          color: isSelected ? Colors.white : const Color(0xFFAEB2BD),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFFD0D4DD),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // ACTIVE WORKSPACE SWITCHER
  // -------------------------------------------------------------
  Widget _buildActiveWorkspace() {
    switch (_selectedMenuIndex) {
      case 0:
        return const EmployeeProfileView();
      case 1:
        return const GenericHrWorkspaceView(
          title: 'Employee Documents',
          subtitle: 'Statutory compliance IDs, wireman licenses, educational records, and contracts',
          icon: Icons.description_outlined,
          primaryActionLabel: 'Upload Document',
          tableHeaders: ['Doc Code', 'Employee', 'Category', 'File Name', 'Uploaded Date', 'Status'],
          sampleRows: [
            ['DOC-2026-001', 'Rahul Verma (EMP-001)', 'Wireman License', 'MH-PWD-WIREMAN-8492.pdf', '2026-09-12', 'VERIFIED'],
            ['DOC-2026-002', 'Amit Deshmukh (EMP-002)', 'Aadhaar Card', 'aadhaar_front_back.pdf', '2026-09-14', 'VERIFIED'],
            ['DOC-2026-003', 'Sunil Pawar (EMP-003)', 'PAN Card', 'pan_card_sunil.pdf', '2026-09-15', 'VERIFIED'],
            ['DOC-2026-004', 'Deepak Patil (EMP-004)', 'Safety Training Cert', 'arc_flash_cert_2026.pdf', '2026-09-20', 'ACTIVE'],
            ['DOC-2026-005', 'Vikram Shinde (EMP-005)', 'Contract Agreement', 'apex_labor_contract.pdf', '2026-09-22', 'ACTIVE'],
          ],
        );
      case 2:
        return const GenericHrWorkspaceView(
          title: 'Recruitment & Applicant Tracking (ATS)',
          subtitle: 'Open job requisitions, shopfloor technical tests, candidate pipeline, and hiring status',
          icon: Icons.person_search_outlined,
          primaryActionLabel: 'Create Requisition',
          tableHeaders: ['Req ID', 'Designation', 'Department', 'Openings', 'Experience', 'Status'],
          sampleRows: [
            ['REQ-2026-01', 'Certified Wireman (Control Panels)', 'Engineering & Plant', '3', '2-4 Years', 'OPEN'],
            ['REQ-2026-02', 'Busbar Specialist & Fabricator', 'Fabrication Bay', '2', '3-5 Years', 'INTERVIEWING'],
            ['REQ-2026-03', 'Panel Testing Engineer (FAT)', 'Testing Bay', '1', '4-6 Years', 'OPEN'],
            ['REQ-2026-04', 'PLC/VFD Automation Engineer', 'Design & R&D', '1', '3-5 Years', 'SHORTLISTING'],
            ['REQ-2026-05', 'Apprentice Wireman (ITI Electrician)', 'Plant Floor', '5', 'Fresher', 'OPEN'],
          ],
        );
      case 3:
        return const GenericHrWorkspaceView(
          title: 'Candidate Interviews & Bay Tests',
          subtitle: 'Interview schedule, wiring bench practical evaluation, and panel design assessment',
          icon: Icons.record_voice_over_outlined,
          primaryActionLabel: 'Schedule Interview',
          tableHeaders: ['Candidate', 'Role', 'Interview Type', 'Scheduled Time', 'Interviewer / Evaluator', 'Stage'],
          sampleRows: [
            ['Santosh Jadhav', 'Certified Wireman', 'Shopfloor Bench Test (Wiring)', 'Tomorrow, 10:30 AM', 'Plant Supervisor (Bay 4)', 'TECHNICAL_ROUND_2'],
            ['Prakash More', 'Busbar Specialist', 'Practical Bending & Torque Test', 'Tomorrow, 02:00 PM', 'Busbar Lead (Bay 2)', 'TECHNICAL_ROUND_1'],
            ['Kavita Nair', 'FAT Testing Engineer', 'High Voltage & Megger Test Assessment', '05 Oct, 11:00 AM', 'Quality & Testing Head', 'MANAGEMENT_ROUND'],
            ['Mahesh Shinde', 'Apprentice Electrician', 'ITI Certificate & Basic Wiring', '06 Oct, 10:00 AM', 'HR Executive', 'INITIAL_SCREENING'],
          ],
        );
      case 4:
        return const ShiftSetupView();
      case 5:
        return const AttendanceLeaveView();
      case 6:
        return const GenericHrWorkspaceView(
          title: 'Leave Types & Entitlements',
          subtitle: 'Policy master for Casual Leave (CL), Sick Leave (SL), Earned Leave (EL/PL), and Maternity/Paternity',
          icon: Icons.article_outlined,
          primaryActionLabel: 'Add Leave Type',
          tableHeaders: ['Type Code', 'Leave Category', 'Annual Quota', 'Carry Forward', 'Encashable', 'Status'],
          sampleRows: [
            ['CL', 'Casual Leave', '12 Days', 'No', 'No', 'ACTIVE'],
            ['SL', 'Sick Leave', '10 Days', 'Up to 5 Days', 'No', 'ACTIVE'],
            ['EL', 'Earned / Privilege Leave (Factories Act)', '15 Days', 'Up to 30 Days', 'Yes (on exit)', 'ACTIVE'],
            ['MAT', 'Maternity Leave (Statutory)', '26 Weeks', 'No', 'No', 'ACTIVE'],
            ['PAT', 'Paternity Leave', '5 Days', 'No', 'No', 'ACTIVE'],
            ['LOP', 'Loss of Pay / Unpaid', 'Unlimited (on approval)', 'No', 'No', 'ACTIVE'],
          ],
        );
      case 7:
        return const GenericHrWorkspaceView(
          title: 'Leave Balances Master',
          subtitle: 'Worker quota balances, accrued leave days, and utilization history',
          icon: Icons.balance_outlined,
          primaryActionLabel: 'Recalculate Accruals',
          tableHeaders: ['Emp Code', 'Employee Name', 'Department', 'CL Balance', 'SL Balance', 'EL Balance', 'Total Available'],
          sampleRows: [
            ['EMP-001', 'Rahul Verma', 'Engineering & Assembly', '6.0', '7.5', '11.0', '24.5 Days'],
            ['EMP-002', 'Amit Deshmukh', 'Wiring & Mounting Bay', '4.0', '5.0', '8.5', '17.5 Days'],
            ['EMP-003', 'Sunil Pawar', 'Busbar Fabrication Bay', '8.0', '6.0', '12.0', '26.0 Days'],
            ['EMP-004', 'Deepak Patil', 'Testing & Commissioning', '5.0', '4.0', '9.0', '18.0 Days'],
            ['EMP-005', 'Vikram Shinde', 'Plant Operations', '7.0', '8.0', '14.0', '29.0 Days'],
          ],
        );
      case 8:
        return const LeaveRequestsView();
      case 9:
        return const PayrollCompensationView();
      case 10:
        return const GenericHrWorkspaceView(
          title: 'Payroll Runs & Bank Registers',
          subtitle: 'Monthly salary disbursement batches, NEFT payment files, and accounting journal integration',
          icon: Icons.credit_card_outlined,
          primaryActionLabel: 'Generate New Batch',
          tableHeaders: ['Batch ID', 'Pay Period', 'Total Employees', 'Gross Amount', 'Net Payout', 'Disbursement Date', 'Status'],
          sampleRows: [
            ['PAY-BATCH-2026-09', 'September 2026', '48 Staff', '₹18,45,000', '₹15,62,400', '2026-10-01', 'PROCESSED / PAID'],
            ['PAY-BATCH-2026-08', 'August 2026', '47 Staff', '₹17,90,000', '₹15,18,200', '2026-09-01', 'PROCESSED / PAID'],
            ['PAY-BATCH-2026-07', 'July 2026', '45 Staff', '₹17,20,000', '₹14,56,800', '2026-08-01', 'PROCESSED / PAID'],
          ],
        );
      case 11:
        return const GenericHrWorkspaceView(
          title: 'Performance & Engineering Goals',
          subtitle: 'Wireman wiring speed KPIs, busbar precision metrics, and testing error rate milestones',
          icon: Icons.track_changes_outlined,
          primaryActionLabel: 'Set Department Goal',
          tableHeaders: ['Goal ID', 'Title', 'Target Group', 'Key Metric', 'Target Date', 'Completion'],
          sampleRows: [
            ['G-2026-01', 'Panel Wiring Zero-Defect Initiative', 'Bay 4 Technicians', '< 1% ferrule error rate', '2026-12-31', '85% ON TRACK'],
            ['G-2026-02', 'FAT High Voltage Testing Efficiency', 'Bay 5 Testing Team', 'Avg 3.5 hrs / panel', '2026-11-30', '92% ACHIEVED'],
            ['G-2026-03', 'Busbar Torque & Sleeve Safety Check', 'Bay 2 Fabricators', '100% torque audit signoff', '2026-10-31', '98% ON TRACK'],
            ['G-2026-04', 'Level 1 to Level 2 Wireman Certifications', 'Apprentices & Trainees', '5 certified technicians', '2026-12-15', '60% IN PROGRESS'],
          ],
        );
      case 12:
        return const GenericHrWorkspaceView(
          title: 'Performance Appraisals & Skill Audits',
          subtitle: 'Annual and bi-annual technician skill evaluations, wage increment reviews, and grade promotions',
          icon: Icons.star,
          primaryActionLabel: 'Initiate Appraisal Cycle',
          tableHeaders: ['Review ID', 'Employee', 'Designation', 'Current Skill Grade', 'Supervisor Rating', 'Recommendation'],
          sampleRows: [
            ['REV-2026-01', 'Rahul Verma', 'Senior Wireman', 'LEVEL_2_WIREMAN', '4.8 / 5.0', 'Promote to Level 3 Busbar Lead'],
            ['REV-2026-02', 'Amit Deshmukh', 'Assembly Technician', 'LEVEL_2_WIREMAN', '4.5 / 5.0', 'Standard Increment + Safety Bonus'],
            ['REV-2026-03', 'Sunil Pawar', 'Busbar Specialist', 'LEVEL_3_BUSBAR_SPECIALIST', '4.9 / 5.0', 'Appointed Bay 2 Shift Incharge'],
            ['REV-2026-04', 'Deepak Patil', 'Testing Engineer', 'LEVEL_4_TESTING_EXPERT', '5.0 / 5.0', 'Quality Lead Designation'],
          ],
        );
      case 13:
        return const GenericHrWorkspaceView(
          title: 'Learning & Development (Shopfloor Training)',
          subtitle: 'Arc-flash safety certification, high-voltage FAT test procedures, and wiring standards workshops',
          icon: Icons.menu_book_outlined,
          primaryActionLabel: 'Schedule Workshop',
          tableHeaders: ['Program ID', 'Training Program Name', 'Instructor / Agency', 'Target Audience', 'Duration', 'Compliance'],
          sampleRows: [
            ['TRN-2026-01', 'High Voltage FAT Safety & Arc Flash Protection', 'National Safety Council India', 'Testing & Wiring Staff', '2 Days (16 Hrs)', 'MANDATORY STATUTORY'],
            ['TRN-2026-02', 'Precision Copper Busbar Bending & Torque Calib', 'Rittal & Schneider Tech Trainers', 'Bay 2 Fabricators', '1 Day (8 Hrs)', 'TECHNICAL CERTIFIED'],
            ['TRN-2026-03', 'PLC & VFD Control Loop Wiring Best Practices', 'Internal Senior Engineering Lead', 'Level 2 & Trainee Wiremen', '3 Days (12 Hrs)', 'INTERNAL SKILL UPGRADE'],
            ['TRN-2026-04', 'Factories Act Industrial Safety & First Aid Drills', 'MIDC Plant Safety Inspectorate', 'All Shopfloor Workers', '1 Day (4 Hrs)', 'ANNUAL EHS COMPLIANCE'],
          ],
        );
      case 14:
        return const GenericHrWorkspaceView(
          title: 'Offboarding & Separation Formalities',
          subtitle: 'Resignation requests, asset recovery (toolkits, PPE gear), PF settlement transfer, and experience letters',
          icon: Icons.meeting_room_outlined,
          primaryActionLabel: 'Initiate Separation',
          tableHeaders: ['Case ID', 'Employee', 'Department', 'Notice Date', 'Last Working Day', 'Clearance Status'],
          sampleRows: [
            ['SEP-2026-01', 'Ganesh Kulkarni', 'Fabrication Bay', '2026-09-10', '2026-10-10', 'TOOLS RETURNED / PENDING HR SIGN'],
            ['SEP-2026-02', 'Pooja Sharma', 'Accounts & Finance', '2026-08-25', '2026-09-25', 'FULL & FINAL SETTLED (PAID)'],
          ],
        );
      default:
        return const EmployeeProfileView();
    }
  }

  // -------------------------------------------------------------
  // HEADER
  // -------------------------------------------------------------
  Widget _buildHeader({required bool showMenuButton}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2024),
        border: Border(bottom: BorderSide(color: Color(0xFF2E3238))),
      ),
      child: Row(
        children: [
          if (showMenuButton)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 20),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                tooltip: 'Open HR Navigation Menu',
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.arrow_back, size: 14),
            label: const Text('Back to Menu'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _showHelpDialog,
            icon: const Icon(Icons.help_outline, size: 14),
            label: const Text('Help'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Human Resources',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFFF26522), size: 20),
            SizedBox(width: 8),
            Text('Human Resources Help', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Human Resources Navigation:\n\n'
          '• Employee Profile: Enter or edit personal, contact, and employment information.\n'
          '• Shift Setup: Indian Factories Act shift timings, grace minutes, and allowances.\n'
          '• Attendance & Leave: Biometric punches and Form 25 muster roll records.\n'
          '• Payroll & Compensation: Salary calculations, Overtime (Sec 59), EPF 12%, and ESI.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF26522),
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
