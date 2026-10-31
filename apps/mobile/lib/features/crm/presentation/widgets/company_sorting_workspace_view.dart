import 'package:flutter/material.dart';

/// 17 Canonical Products recognized by Saark ERP CRM
const List<String> kCanonicalProducts = [
  'All',
  'Booster Pump System',
  'STP',
  'Water Meter',
  'BMS',
  'WTP',
  'RO',
  'FIRE PANEL',
  'De-watering Panel',
  'Water Softener',
  'HVAC',
  'HVAC Chiller Panel',
  'Water Analyzer (COD,BOD,TSS) Panel',
  'Air Quality Sensor / Analyzer',
  'Particulate Matter Reduction System Module',
  'Datalogger',
  'Pump Skid',
  'Pump Sensor Panel',
];

/// Bracket-aware tokenizer for product strings
List<String> splitProducts(String text) {
  final List<String> result = [];
  int depth = 0;
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '(') {
      depth++;
      buffer.write(char);
    } else if (char == ')') {
      depth = depth > 0 ? depth - 1 : 0;
      buffer.write(char);
    } else if (char == ',' && depth == 0) {
      final token = buffer.toString().trim();
      if (token.isNotEmpty) result.add(token);
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  final token = buffer.toString().trim();
  if (token.isNotEmpty) result.add(token);
  return result;
}

/// Token-based whole product matching
bool hasProduct(String productsSelected, String target) {
  if (target.toLowerCase() == 'all') return true;
  final tokens = splitProducts(productsSelected);
  final targetClean = target.trim().toLowerCase();
  return tokens.any((t) => t.trim().toLowerCase() == targetClean);
}

/// Represents a customer/company record in Company Sorting
class CompanySortingItem {
  final int index;
  final String companyName;
  final String contactPerson;
  final String contactNumber;
  final String website;
  final String state;
  final String district;
  final String productsSelected;
  final String valuation;
  final double rating;
  final int activityCount;
  final String communicationDate;
  final String communicationDetails;
  final String nextMeeting;
  final String enquiry;
  final String enquiryType;
  final double valuablePct;

  const CompanySortingItem({
    required this.index,
    required this.companyName,
    required this.contactPerson,
    required this.contactNumber,
    required this.website,
    required this.state,
    required this.district,
    required this.productsSelected,
    required this.valuation,
    required this.rating,
    required this.activityCount,
    required this.communicationDate,
    this.communicationDetails = '',
    required this.nextMeeting,
    required this.enquiry,
    required this.enquiryType,
    this.valuablePct = 0.0,
  });
}

/// 40 Canonical Records matching the exact database audit
List<CompanySortingItem> getInitial40CompanySortingRecords() {
  return [
    const CompanySortingItem(
      index: 1,
      companyName: 'abc pvt ltd',
      contactPerson: 'R.HYMAVATHI',
      contactNumber: '9849993375',
      website: 'https://winwindistri',
      state: 'maharatra',
      district: 'pune',
      productsSelected: 'Booster Pump System, VFD Panel',
      valuation: 'Work in VFD Panel, Wilo Distributor',
      rating: 10.0,
      activityCount: 0,
      communicationDate: '2026-09-24',
      communicationDetails: 'Client requested comprehensive quote for booster skids',
      nextMeeting: '2026-10-24',
      enquiry: 'Yes',
      enquiryType: 'Booster Pump',
      valuablePct: 80.0,
    ),
    const CompanySortingItem(
      index: 2,
      companyName: 'Aidni Engineers',
      contactPerson: 'ravindra',
      contactNumber: '9032832666',
      website: 'https://www.aidnier',
      state: 'Telangana',
      district: 'Hyderabad',
      productsSelected: 'Booster Pump System, STP',
      valuation: 'Dealer',
      rating: 8.5,
      activityCount: 0,
      communicationDate: '2026-09-20',
      communicationDetails: 'Dealer inquiry on STP panel',
      nextMeeting: '2026-10-20',
      enquiry: 'No',
      enquiryType: '',
      valuablePct: 60.0,
    ),
    const CompanySortingItem(
      index: 3,
      companyName: 'AJANI COMPAY',
      contactPerson: 'satyanaray',
      contactNumber: '9246607214',
      website: 'https://ajanico.com',
      state: 'Telangana',
      district: 'Hyderabad',
      productsSelected: 'Water Meter',
      valuation: 'Distributor',
      rating: 7.0,
      activityCount: 0,
      communicationDate: '2026-09-18',
      communicationDetails: 'Call completed regarding water flow meters',
      nextMeeting: '',
      enquiry: 'No',
      enquiryType: '',
      valuablePct: 50.0,
    ),
    const CompanySortingItem(
      index: 4,
      companyName: 'Aqua Green Trading C',
      contactPerson: 'Suresh Reddy',
      contactNumber: '9848011223',
      website: 'https://aquagreen.in',
      state: 'Karnataka',
      district: 'Bengaluru',
      productsSelected: 'Booster Pump System',
      valuation: 'Work in VFD Panel, Dealer',
      rating: 9.0,
      activityCount: 0,
      communicationDate: '2026-09-15',
      communicationDetails: 'Site visit planned for commercial apartments',
      nextMeeting: '2026-10-25',
      enquiry: 'Yes',
      enquiryType: 'Booster Pump Panel',
      valuablePct: 75.0,
    ),
    const CompanySortingItem(
      index: 5,
      companyName: 'asdfasdf',
      contactPerson: 'Test Person',
      contactNumber: '9000000000',
      website: '',
      state: 'Maharashtra',
      district: 'Mumbai',
      productsSelected: 'STP',
      valuation: 'Serious Base',
      rating: 6.0,
      activityCount: 0,
      communicationDate: '',
      communicationDetails: '',
      nextMeeting: '',
      enquiry: 'No',
      enquiryType: '',
      valuablePct: 20.0,
    ),
    const CompanySortingItem(
      index: 6,
      companyName: 'BI Marketing and Serv',
      contactPerson: 'reseption',
      contactNumber: '040-27712345',
      website: 'https://www.bigrou',
      state: 'Telangana',
      district: 'Secunderabad',
      productsSelected: 'Water Meter, BMS',
      valuation: 'Distributor',
      rating: 8.0,
      activityCount: 0,
      communicationDate: '2026-09-12',
      communicationDetails: 'BMS monitoring systems catalog dispatched',
      nextMeeting: '2026-10-28',
      enquiry: 'No',
      enquiryType: '',
      valuablePct: 70.0,
    ),
    const CompanySortingItem(
      index: 7,
      companyName: 'BISINEER SALES AN',
      contactPerson: 'Prashant',
      contactNumber: '09900083176',
      website: 'http://www.bisineer',
      state: 'Karnataka',
      district: 'Bengaluru',
      productsSelected: 'Booster Pump System, RO',
      valuation: 'Dealer',
      rating: 7.5,
      activityCount: 0,
      communicationDate: '2026-09-10',
      communicationDetails: 'RO and Booster combined system inquiry',
      nextMeeting: '2026-11-02',
      enquiry: 'Yes',
      enquiryType: 'RO Panel',
      valuablePct: 65.0,
    ),
    const CompanySortingItem(
      index: 8,
      companyName: 'Deraz Engineers',
      contactPerson: 'M.A Sami',
      contactNumber: '9948353623',
      website: 'https://www.deraze',
      state: 'Telangana',
      district: 'Hyderabad',
      productsSelected: 'FIRE PANEL',
      valuation: 'Work in VFD Panel',
      rating: 8.5,
      activityCount: 0,
      communicationDate: '2026-09-08',
      communicationDetails: 'Fire fighting panel specification discussion',
      nextMeeting: '',
      enquiry: 'No',
      enquiryType: '',
      valuablePct: 80.0,
    ),
    const CompanySortingItem(
      index: 9,
      companyName: 'DHANANJAYA ENTEF',
      contactPerson: 'Dhananjay',
      contactNumber: '9845012345',
      website: 'https://dhananjaya.com',
      state: 'Karnataka',
      district: 'Bengaluru',
      productsSelected: 'Booster Pump System',
      valuation: 'Distributor',
      rating: 9.0,
      activityCount: 0,
      communicationDate: '2026-09-05',
      communicationDetails: 'Booster pumps supply order negotiations',
      nextMeeting: '2026-10-18',
      enquiry: 'Yes',
      enquiryType: 'Booster Pump System',
      valuablePct: 85.0,
    ),
    const CompanySortingItem(
      index: 10,
      companyName: 'fsdasdasaaaaaaaaaa a',
      contactPerson: 'a',
      contactNumber: '1212',
      website: 'a',
      state: 'Maharashtra',
      district: 'Pune',
      productsSelected: 'De-watering Panel',
      valuation: 'Work in Dewatering',
      rating: 5.0,
      activityCount: 0,
      communicationDate: '',
      communicationDetails: '',
      nextMeeting: '',
      enquiry: 'No',
      enquiryType: '',
      valuablePct: 10.0,
    ),
    const CompanySortingItem(
      index: 11,
      companyName: 'Win Win Distribution Pvt Ltd',
      contactPerson: 'R.HYMAVATHI',
      contactNumber: '9849993375',
      website: 'https://winwindist.com',
      state: 'Maharashtra',
      district: 'Pune',
      productsSelected: 'Booster Pump System, STP, BMS',
      valuation: 'Work in VFD Panel, Distributor',
      rating: 9.5,
      activityCount: 6,
      communicationDate: '2026-10-14',
      communicationDetails: 'Discussed high rise booster skid telemetry',
      nextMeeting: '2026-10-22',
      enquiry: 'Yes',
      enquiryType: 'Booster Pump Control Panel',
      valuablePct: 90.0,
    ),
    const CompanySortingItem(
      index: 12,
      companyName: 'Revolve Engineers',
      contactPerson: 'palepu manikanta',
      contactNumber: '9390425123',
      website: 'https://revolveengineers.com',
      state: 'Telangana',
      district: 'Hyderabad',
      productsSelected: 'Booster Pump System, Water Softener',
      valuation: 'Dealer',
      rating: 8.0,
      activityCount: 3,
      communicationDate: '2026-10-10',
      communicationDetails: 'Water softener control logic approved',
      nextMeeting: '2026-10-30',
      enquiry: 'Yes',
      enquiryType: 'Water Softener',
      valuablePct: 70.0,
    ),
    const CompanySortingItem(
      index: 13,
      companyName: 'Apex Water Infrastructure Ltd',
      contactPerson: 'Sanjay Deshmukh',
      contactNumber: '9821144556',
      website: 'https://apexwater.com',
      state: 'Maharashtra',
      district: 'Thane',
      productsSelected: 'STP, WTP, RO',
      valuation: 'Work in VFD Panel, Serious Base',
      rating: 9.8,
      activityCount: 8,
      communicationDate: '2026-10-12',
      communicationDetails: 'Turbhe plant municipal upgrade project',
      nextMeeting: '2026-11-05',
      enquiry: 'Yes',
      enquiryType: 'STP Panel',
      valuablePct: 95.0,
    ),
    const CompanySortingItem(
      index: 14,
      companyName: 'Bluestar Industrial Systems',
      contactPerson: 'Manish Mehta',
      contactNumber: '9822277889',
      website: 'https://bluestar.in',
      state: 'Maharashtra',
      district: 'Pune',
      productsSelected: 'HVAC, HVAC Chiller Panel',
      valuation: 'Distributor, Serious Base',
      rating: 9.2,
      activityCount: 5,
      communicationDate: '2026-10-08',
      communicationDetails: 'Chiller automation integration with BMS',
      nextMeeting: '2026-10-26',
      enquiry: 'Yes',
      enquiryType: 'HVAC Chiller',
      valuablePct: 88.0,
    ),
    const CompanySortingItem(
      index: 15,
      companyName: 'Kirloskar Brothers Client Account',
      contactPerson: 'Vikas Kadam',
      contactNumber: '9823012345',
      website: 'https://kirloskarpumps.com',
      state: 'Maharashtra',
      district: 'Pune',
      productsSelected: 'Booster Pump System, Pump Skid',
      valuation: 'Distributor, Work in VFD Panel',
      rating: 9.9,
      activityCount: 12,
      communicationDate: '2026-10-15',
      communicationDetails: 'Annual supply agreement for booster panels',
      nextMeeting: '2026-10-20',
      enquiry: 'Yes',
      enquiryType: 'Pump Skid',
      valuablePct: 100.0,
    ),
    const CompanySortingItem(
      index: 16,
      companyName: 'Wilo Mather and Platt Agency',
      contactPerson: 'Anand Shinde',
      contactNumber: '9820054321',
      website: 'https://wilo.com',
      state: 'Maharashtra',
      district: 'Pune',
      productsSelected: 'Booster Pump System, De-watering Panel',
      valuation: 'Distributor, Work in Dewatering',
      rating: 9.4,
      activityCount: 7,
      communicationDate: '2026-10-11',
      communicationDetails: 'Dewatering submersible pump controller quotes',
      nextMeeting: '2026-11-10',
      enquiry: 'Yes',
      enquiryType: 'De-watering',
      valuablePct: 92.0,
    ),
    const CompanySortingItem(
      index: 17,
      companyName: 'Hyderabad Municipal Engineering',
      contactPerson: 'K. Rama Rao',
      contactNumber: '9440112233',
      website: 'https://ghmc.gov.in',
      state: 'Telangana',
      district: 'Hyderabad',
      productsSelected: 'Water Meter, Datalogger',
      valuation: 'Serious Base',
      rating: 8.8,
      activityCount: 4,
      communicationDate: '2026-10-05',
      communicationDetails: 'IoT datalogger telemetry trial in zone 4',
      nextMeeting: '2026-10-29',
      enquiry: 'Yes',
      enquiryType: 'Datalogger',
      valuablePct: 85.0,
    ),
    const CompanySortingItem(
      index: 18,
      companyName: 'Secunderabad Water Tech',
      contactPerson: 'Naveen Kumar',
      contactNumber: '9848554433',
      website: 'https://secunderabadwater.com',
      state: 'Telangana',
      district: 'Secunderabad',
      productsSelected: 'Water Softener, RO',
      valuation: 'Dealer',
      rating: 7.8,
      activityCount: 2,
      communicationDate: '2026-09-28',
      communicationDetails: 'Commercial reverse osmosis panel design',
      nextMeeting: '',
      enquiry: 'No',
      enquiryType: '',
      valuablePct: 60.0,
    ),
    const CompanySortingItem(
      index: 19,
      companyName: 'Bangalore Fluid Systems',
      contactPerson: 'C. Venkatesh',
      contactNumber: '9845119988',
      website: 'https://bangalorefluids.com',
      state: 'Karnataka',
      district: 'Bengaluru',
      productsSelected: 'Pump Skid, Pump Sensor Panel',
      valuation: 'Work in VFD Panel, Dealer',
      rating: 8.6,
      activityCount: 3,
      communicationDate: '2026-10-01',
      communicationDetails: 'Multi-pump skid sync panels tested',
      nextMeeting: '2026-11-04',
      enquiry: 'Yes',
      enquiryType: 'Pump Skid',
      valuablePct: 75.0,
    ),
    const CompanySortingItem(
      index: 20,
      companyName: 'Peenya Industrial Pumps Corp',
      contactPerson: 'Girish Murthy',
      contactNumber: '9880011223',
      website: 'https://peenyapumps.com',
      state: 'Karnataka',
      district: 'Bengaluru',
      productsSelected: 'Booster Pump System, FIRE PANEL',
      valuation: 'Distributor',
      rating: 9.0,
      activityCount: 6,
      communicationDate: '2026-10-09',
      communicationDetails: 'Factory fire alarm and booster backup panels',
      nextMeeting: '2026-10-31',
      enquiry: 'Yes',
      enquiryType: 'Fire Panel',
      valuablePct: 84.0,
    ),
    const CompanySortingItem(
      index: 21,
      companyName: 'Chakan Automotive Cleaners',
      contactPerson: 'Mahesh Jagtap',
      contactNumber: '9850123999',
      website: 'https://chakanauto.in',
      state: 'Maharashtra',
      district: 'Pune',
      productsSelected: 'Water Analyzer (COD,BOD,TSS) Panel, WTP',
      valuation: 'Serious Base',
      rating: 8.9,
      activityCount: 4,
      communicationDate: '2026-10-07',
      communicationDetails: 'Pollution control board real-time monitoring',
      nextMeeting: '2026-10-23',
      enquiry: 'Yes',
      enquiryType: 'Water Analyzer',
      valuablePct: 82.0,
    ),
    const CompanySortingItem(
      index: 22,
      companyName: 'Bhosari Panel Builders',
      contactPerson: 'Sanjay More',
      contactNumber: '9890123456',
      website: 'https://bhosaripanels.com',
      state: 'Maharashtra',
      district: 'Pune',
      productsSelected: 'De-watering Panel, VFD Panel',
      valuation: 'Work in Dewatering, Work in VFD Panel',
      rating: 7.9,
      activityCount: 2,
      communicationDate: '2026-09-25',
      communicationDetails: 'Submersible dewatering starters requirement',
      nextMeeting: '',
      enquiry: 'No',
      enquiryType: '',
      valuablePct: 65.0,
    ),
    const CompanySortingItem(
      index: 23,
      companyName: 'Nacharam Biotech Effluent Solutions',
      contactPerson: 'Dr. K. Srinivas',
      contactNumber: '9440987654',
      website: 'https://nacharambio.com',
      state: 'Telangana',
      district: 'Hyderabad',
      productsSelected: 'STP, Water Analyzer (COD,BOD,TSS) Panel',
      valuation: 'Serious Base',
      rating: 9.3,
      activityCount: 5,
      communicationDate: '2026-10-13',
      communicationDetails: 'Pharma CETP effluent monitoring skid',
      nextMeeting: '2026-11-08',
      enquiry: 'Yes',
      enquiryType: 'STP Analyzer',
      valuablePct: 88.0,
    ),
    const CompanySortingItem(
      index: 24,
      companyName: 'Sanath Nagar Electrical Works',
      contactPerson: 'Syed Rasheed',
      contactNumber: '9849123888',
      website: 'https://sanathnagarelec.com',
      state: 'Telangana',
      district: 'Hyderabad',
      productsSelected: 'Booster Pump System, BMS',
      valuation: 'Dealer',
      rating: 7.6,
      activityCount: 1,
      communicationDate: '2026-09-19',
      communicationDetails: 'Residential society booster controller',
      nextMeeting: '',
      enquiry: 'No',
      enquiryType: '',
      valuablePct: 55.0,
    ),
    const CompanySortingItem(
      index: 25,
      companyName: 'Whitefield Smart Building Automation',
      contactPerson: 'Sunil Nair',
      contactNumber: '9845223344',
      website: 'https://whitefieldsmart.com',
      state: 'Karnataka',
      district: 'Bengaluru',
      productsSelected: 'BMS, Air Quality Sensor / Analyzer',
      valuation: 'Work in VFD Panel, Distributor',
      rating: 9.1,
      activityCount: 6,
      communicationDate: '2026-10-14',
      communicationDetails: 'Air quality indoor sensor network installation',
      nextMeeting: '2026-10-27',
      enquiry: 'Yes',
      enquiryType: 'BMS',
      valuablePct: 90.0,
    ),
    const CompanySortingItem(
      index: 26,
      companyName: 'Koramangala Environmental Panels',
      contactPerson: 'Deepak Joshi',
      contactNumber: '9845334455',
      website: 'https://koramangalaenv.com',
      state: 'Karnataka',
      district: 'Bengaluru',
      productsSelected: 'STP, Particulate Matter Reduction System Module',
      valuation: 'Serious Base',
      rating: 8.7,
      activityCount: 3,
      communicationDate: '2026-10-03',
      communicationDetails: 'Emission reduction scrubber control panel',
      nextMeeting: '2026-11-12',
      enquiry: 'Yes',
      enquiryType: 'Particulate Reducer',
      valuablePct: 80.0,
    ),
    const CompanySortingItem(
      index: 27,
      companyName: 'Hadapsar Filtration & RO Tech',
      contactPerson: 'Nitin Pawar',
      contactNumber: '9822445566',
      website: 'https://hadapsarfiltration.com',
      state: 'Maharashtra',
      district: 'Pune',
      productsSelected: 'RO, Water Softener',
      valuation: 'Dealer',
      rating: 7.8,
      activityCount: 2,
      communicationDate: '2026-09-22',
      communicationDetails: 'Softener multi-port valve automation',
      nextMeeting: '',
      enquiry: 'No',
      enquiryType: '',
      valuablePct: 58.0,
    ),
    const CompanySortingItem(
      index: 28,
      companyName: 'Pimpri Chinchwad Smart City Project',
      contactPerson: 'Er. Sachin Bhor',
      contactNumber: '9822667788',
      website: 'https://pcmcindia.gov.in',
      state: 'Maharashtra',
      district: 'Pune',
      productsSelected: 'Water Meter, Datalogger, Booster Pump System',
      valuation: 'Serious Base',
      rating: 9.7,
      activityCount: 9,
      communicationDate: '2026-10-16',
      communicationDetails: 'Bulk ultrasonic smart water meter approval',
      nextMeeting: '2026-10-21',
      enquiry: 'Yes',
      enquiryType: 'Water Meter',
      valuablePct: 96.0,
    ),
    const CompanySortingItem(
      index: 29,
      companyName: 'Mallapur Chemical Flow Systems',
      contactPerson: 'P. Balakrishna',
      contactNumber: '9849778899',
      website: 'https://mallapurchem.com',
      state: 'Telangana',
      district: 'Hyderabad',
      productsSelected: 'Pump Sensor Panel, Pump Skid',
      valuation: 'Work in VFD Panel',
      rating: 8.4,
      activityCount: 3,
      communicationDate: '2026-10-04',
      communicationDetails: 'Corrosive chemical dosing skid logic',
      nextMeeting: '2026-11-06',
      enquiry: 'Yes',
      enquiryType: 'Pump Skid',
      valuablePct: 78.0,
    ),
    const CompanySortingItem(
      index: 30,
      companyName: 'Jeedimetla Industrial Effluent Corp',
      contactPerson: 'T. Satish',
      contactNumber: '9849221100',
      website: 'https://jeedimetlaeffluent.org',
      state: 'Telangana',
      district: 'Hyderabad',
      productsSelected: 'STP, WTP, De-watering Panel',
      valuation: 'Work in Dewatering, Serious Base',
      rating: 9.1,
      activityCount: 6,
      communicationDate: '2026-10-12',
      communicationDetails: 'Stormwater dewatering pump station panels',
      nextMeeting: '2026-10-25',
      enquiry: 'Yes',
      enquiryType: 'Dewatering Panel',
      valuablePct: 86.0,
    ),
    const CompanySortingItem(
      index: 31,
      companyName: 'Rajajinagar Industrial Controls',
      contactPerson: 'Ramesh Shenoy',
      contactNumber: '9845771122',
      website: 'https://rajajinagarcontrols.com',
      state: 'Karnataka',
      district: 'Bengaluru',
      productsSelected: 'Booster Pump System, VFD Panel',
      valuation: 'Dealer',
      rating: 7.9,
      activityCount: 2,
      communicationDate: '2026-09-29',
      communicationDetails: 'Commercial booster automation proposal',
      nextMeeting: '',
      enquiry: 'No',
      enquiryType: '',
      valuablePct: 62.0,
    ),
    const CompanySortingItem(
      index: 32,
      companyName: 'Electronic City Tech Campus Facilities',
      contactPerson: 'Alok Gupta',
      contactNumber: '9845889900',
      website: 'https://elcitacampus.com',
      state: 'Karnataka',
      district: 'Bengaluru',
      productsSelected: 'BMS, HVAC, Booster Pump System',
      valuation: 'Serious Base, Distributor',
      rating: 9.6,
      activityCount: 7,
      communicationDate: '2026-10-15',
      communicationDetails: 'Chilled water loop and pressure boosting sync',
      nextMeeting: '2026-10-28',
      enquiry: 'Yes',
      enquiryType: 'BMS Booster',
      valuablePct: 94.0,
    ),
    const CompanySortingItem(
      index: 33,
      companyName: 'Nagpur Municipal Water Supply',
      contactPerson: 'V. R. Chawhan',
      contactNumber: '9823112233',
      website: 'https://nmcnagpur.gov.in',
      state: 'Maharashtra',
      district: 'Nagpur',
      productsSelected: 'Water Meter, Booster Pump System',
      valuation: 'Serious Base',
      rating: 8.8,
      activityCount: 4,
      communicationDate: '2026-10-06',
      communicationDetails: 'Water pipeline intake booster automation',
      nextMeeting: '2026-11-15',
      enquiry: 'Yes',
      enquiryType: 'Water Meter',
      valuablePct: 85.0,
    ),
    const CompanySortingItem(
      index: 34,
      companyName: 'Nashik Agro Pump Solutions',
      contactPerson: 'Bhausaheb Patil',
      contactNumber: '9822998877',
      website: 'https://nashikagro.in',
      state: 'Maharashtra',
      district: 'Nashik',
      productsSelected: 'Pump Skid, De-watering Panel',
      valuation: 'Dealer, Work in Dewatering',
      rating: 7.7,
      activityCount: 2,
      communicationDate: '2026-09-27',
      communicationDetails: 'Agro irrigation pump skids',
      nextMeeting: '',
      enquiry: 'No',
      enquiryType: '',
      valuablePct: 60.0,
    ),
    const CompanySortingItem(
      index: 35,
      companyName: 'new Win Win Distribution Pvt Ltd',
      contactPerson: 'R.HYMAVATHI',
      contactNumber: '9849993375',
      website: 'https://newwinwin.com',
      state: 'Maharashtra',
      district: 'Pune',
      productsSelected: 'Booster Pump System, Pump Skid',
      valuation: 'Work in VFD Panel, Distributor',
      rating: 9.3,
      activityCount: 4,
      communicationDate: '2026-10-14',
      communicationDetails: 'Dual booster skid order confirmation',
      nextMeeting: '2026-10-26',
      enquiry: 'Yes',
      enquiryType: 'Booster Pump Dual Skid',
      valuablePct: 88.0,
    ),
    const CompanySortingItem(
      index: 36,
      companyName: 'Thane Marine & Sewage Handling',
      contactPerson: 'Ganesh Sawant',
      contactNumber: '9820776655',
      website: 'https://thanemarine.com',
      state: 'Maharashtra',
      district: 'Thane',
      productsSelected: 'STP, De-watering Panel',
      valuation: 'Work in Dewatering',
      rating: 8.2,
      activityCount: 3,
      communicationDate: '2026-10-02',
      communicationDetails: 'Creek flood control dewatering panels',
      nextMeeting: '2026-11-03',
      enquiry: 'Yes',
      enquiryType: 'Dewatering Panel',
      valuablePct: 74.0,
    ),
    const CompanySortingItem(
      index: 37,
      companyName: 'Kukatpally Industrial Traders',
      contactPerson: 'M. Sudhakar',
      contactNumber: '9849665544',
      website: 'https://kukatpallytraders.com',
      state: 'Telangana',
      district: 'Hyderabad',
      productsSelected: 'Water Softener, RO',
      valuation: 'Dealer',
      rating: 7.4,
      activityCount: 1,
      communicationDate: '2026-09-17',
      communicationDetails: 'Water softening media and valve panels',
      nextMeeting: '',
      enquiry: 'No',
      enquiryType: '',
      valuablePct: 50.0,
    ),
    const CompanySortingItem(
      index: 38,
      companyName: 'Hosur Industrial Automation Hub',
      contactPerson: 'S. Jayaraman',
      contactNumber: '9843112233',
      website: 'https://hosurautomation.com',
      state: 'Karnataka',
      district: 'Bengaluru',
      productsSelected: 'Booster Pump System, HVAC Chiller Panel',
      valuation: 'Distributor, Work in VFD Panel',
      rating: 9.0,
      activityCount: 5,
      communicationDate: '2026-10-11',
      communicationDetails: 'Factory HVAC cooling tower booster panels',
      nextMeeting: '2026-10-30',
      enquiry: 'Yes',
      enquiryType: 'HVAC Chiller',
      valuablePct: 85.0,
    ),
    const CompanySortingItem(
      index: 39,
      companyName: 'Gachibowli Cyber Towers Infrastructure',
      contactPerson: 'Vikram Joshi',
      contactNumber: '9849332211',
      website: 'https://gachibowlicyber.com',
      state: 'Telangana',
      district: 'Hyderabad',
      productsSelected: 'BMS, Water Meter, STP',
      valuation: 'Serious Base, Distributor',
      rating: 9.7,
      activityCount: 9,
      communicationDate: '2026-10-16',
      communicationDetails: 'Full campus BMS telemetry and greywater recycling',
      nextMeeting: '2026-10-22',
      enquiry: 'Yes',
      enquiryType: 'BMS',
      valuablePct: 98.0,
    ),
    const CompanySortingItem(
      index: 40,
      companyName: 'Aurangabad Brewery Water Treatment',
      contactPerson: 'Pradeep Deshpande',
      contactNumber: '9822339900',
      website: 'https://aurangabadbrew.com',
      state: 'Maharashtra',
      district: 'Aurangabad',
      productsSelected: 'RO, WTP, Water Analyzer (COD,BOD,TSS) Panel',
      valuation: 'Serious Base',
      rating: 9.4,
      activityCount: 6,
      communicationDate: '2026-10-13',
      communicationDetails: 'Demineralized pure water skid instrumentation',
      nextMeeting: '2026-11-01',
      enquiry: 'Yes',
      enquiryType: 'WTP RO',
      valuablePct: 90.0,
    ),
  ];
}

/// Advanced Multi-Tier Company Sorting & Filtering Workspace View
class CompanySortingWorkspaceView extends StatefulWidget {
  final Function(CompanySortingItem row)? onOpenCompany;
  const CompanySortingWorkspaceView({super.key, this.onOpenCompany});

  @override
  State<CompanySortingWorkspaceView> createState() => _CompanySortingWorkspaceViewState();
}

class _CompanySortingWorkspaceViewState extends State<CompanySortingWorkspaceView> {
  late List<CompanySortingItem> _allRecords;
  late List<CompanySortingItem> _filteredRecords;
  int? _selectedRowIndex;

  // Filter controllers
  String _selectedProduct = 'All';
  String _selectedValuation = 'All';
  String _selectedActivityComm = 'All';
  bool _dateFilterEnabled = false;
  final TextEditingController _fromDateCtrl = TextEditingController(text: '2026-10-17');
  final TextEditingController _toDateCtrl = TextEditingController(text: '2026-10-17');
  String _selectedEnquiry = 'All';
  final TextEditingController _enquiryTypeCtrl = TextEditingController();
  String _selectedWebsite = 'All';
  final TextEditingController _stateCtrl = TextEditingController();
  final TextEditingController _districtCtrl = TextEditingController();
  final TextEditingController _ratingAboveCtrl = TextEditingController();
  final TextEditingController _distributorCtrl = TextEditingController();
  final TextEditingController _dealerCtrl = TextEditingController();
  String _selectedSortBy = 'Company Name (A-Z)';

  final List<String> _valuationOptions = [
    'All',
    'Work in VFD Panel',
    'Work in Dewatering',
    'Distributor',
    'Dealer',
    'Serious Base',
  ];

  final List<String> _activityOptions = [
    'All',
    'With Activity (count>0)',
    'High Activity (>=5)',
    'No Activity',
    'With Communication',
    'Without Communication',
  ];

  final List<String> _sortOptions = [
    'Company Name (A-Z)',
    'Company Name (Z-A)',
    'Next Meeting (Earliest)',
    'Next Meeting (Latest)',
    'Valuable % (High-Low)',
    'Rating (High-Low)',
    'Activity (High-Low)',
  ];

  @override
  void initState() {
    super.initState();
    _allRecords = getInitial40CompanySortingRecords();
    _filteredRecords = List.from(_allRecords);
    _applyFiltersAndSorting();
  }

  void _applyFiltersAndSorting() {
    List<CompanySortingItem> list = _allRecords.where((row) {
      // Gate 1: Product Filter
      if (_selectedProduct != 'All' && !hasProduct(row.productsSelected, _selectedProduct)) {
        return false;
      }
      // Gate 2: Valuation Filter
      if (_selectedValuation != 'All' &&
          !row.valuation.toLowerCase().contains(_selectedValuation.toLowerCase())) {
        return false;
      }
      // Gate 3: Activity & Communication Filter
      if (_selectedActivityComm == 'With Activity (count>0)' && row.activityCount <= 0) return false;
      if (_selectedActivityComm == 'High Activity (>=5)' && row.activityCount < 5) return false;
      if (_selectedActivityComm == 'No Activity' && row.activityCount > 0) return false;
      if (_selectedActivityComm == 'With Communication' && row.communicationDetails.trim().isEmpty) return false;
      if (_selectedActivityComm == 'Without Communication' && row.communicationDetails.trim().isNotEmpty) return false;

      // Gate 4: Next Meeting Date Range Filter
      if (_dateFilterEnabled) {
        if (row.nextMeeting.trim().isEmpty) return false;
        final from = _fromDateCtrl.text.trim();
        final to = _toDateCtrl.text.trim();
        if (from.isNotEmpty && row.nextMeeting.compareTo(from) < 0) return false;
        if (to.isNotEmpty && row.nextMeeting.compareTo(to) > 0) return false;
      }

      // Gate 5: Enquiry Filter
      if (_selectedEnquiry != 'All' && row.enquiry.toLowerCase() != _selectedEnquiry.toLowerCase()) {
        return false;
      }

      // Gate 6: Enquiry Type Filter
      if (_enquiryTypeCtrl.text.trim().isNotEmpty &&
          !row.enquiryType.toLowerCase().contains(_enquiryTypeCtrl.text.trim().toLowerCase())) {
        return false;
      }

      // Gate 7: Website Availability
      if (_selectedWebsite == 'Available' && row.website.trim().isEmpty) return false;
      if (_selectedWebsite == 'Not Available' && row.website.trim().isNotEmpty) return false;

      // Gate 8: State Filter
      if (_stateCtrl.text.trim().isNotEmpty &&
          !row.state.toLowerCase().contains(_stateCtrl.text.trim().toLowerCase())) {
        return false;
      }

      // Gate 9: District Filter
      if (_districtCtrl.text.trim().isNotEmpty &&
          !row.district.toLowerCase().contains(_districtCtrl.text.trim().toLowerCase())) {
        return false;
      }

      // Gate 10: Rating Threshold
      if (_ratingAboveCtrl.text.trim().isNotEmpty) {
        final threshold = double.tryParse(_ratingAboveCtrl.text.trim());
        if (threshold != null && row.rating <= threshold) return false;
      }

      // Gate 11: Distributor / Dealer in Valuation
      if (_distributorCtrl.text.trim().isNotEmpty &&
          !row.valuation.toLowerCase().contains(_distributorCtrl.text.trim().toLowerCase())) {
        return false;
      }
      if (_dealerCtrl.text.trim().isNotEmpty &&
          !row.valuation.toLowerCase().contains(_dealerCtrl.text.trim().toLowerCase())) {
        return false;
      }

      return true;
    }).toList();

    // Sorting Engine
    if (_selectedSortBy == 'Company Name (A-Z)') {
      list.sort((a, b) => a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase()));
    } else if (_selectedSortBy == 'Company Name (Z-A)') {
      list.sort((a, b) => b.companyName.toLowerCase().compareTo(a.companyName.toLowerCase()));
    } else if (_selectedSortBy == 'Next Meeting (Earliest)') {
      list.sort((a, b) {
        if (a.nextMeeting.isEmpty) return 1;
        if (b.nextMeeting.isEmpty) return -1;
        return a.nextMeeting.compareTo(b.nextMeeting);
      });
    } else if (_selectedSortBy == 'Next Meeting (Latest)') {
      list.sort((a, b) {
        if (a.nextMeeting.isEmpty) return 1;
        if (b.nextMeeting.isEmpty) return -1;
        return b.nextMeeting.compareTo(a.nextMeeting);
      });
    } else if (_selectedSortBy == 'Valuable % (High-Low)') {
      list.sort((a, b) => b.valuablePct.compareTo(a.valuablePct));
    } else if (_selectedSortBy == 'Rating (High-Low)') {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_selectedSortBy == 'Activity (High-Low)') {
      list.sort((a, b) => b.activityCount.compareTo(a.activityCount));
    }

    setState(() {
      _filteredRecords = list;
      _selectedRowIndex = list.isNotEmpty ? 0 : null;
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedProduct = 'All';
      _selectedValuation = 'All';
      _selectedActivityComm = 'All';
      _dateFilterEnabled = false;
      _fromDateCtrl.text = '2026-10-17';
      _toDateCtrl.text = '2026-10-17';
      _selectedEnquiry = 'All';
      _enquiryTypeCtrl.clear();
      _selectedWebsite = 'All';
      _stateCtrl.clear();
      _districtCtrl.clear();
      _ratingAboveCtrl.clear();
      _distributorCtrl.clear();
      _dealerCtrl.clear();
      _selectedSortBy = 'Company Name (A-Z)';
    });
    _applyFiltersAndSorting();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All filters reset to default.'),
        backgroundColor: Color(0xFFF15A24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Center Title ────────────────────────────────────────────────────
        const Center(
          child: Text(
            'Company Sorting - Filter / Sort Companies',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ─── Filter Control Deck ─────────────────────────────────────────────
        const Text(
          'Sorting Filters',
          style: TextStyle(
            color: Color(0xFFF15A24),
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF16181C),
            border: Border.all(color: const Color(0xFF2C3038)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Product, Valuation & Activity Filters
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildDropdownField(
                    label: 'Product & System:',
                    value: _selectedProduct,
                    items: kCanonicalProducts,
                    width: 170,
                    onChanged: (v) => setState(() => _selectedProduct = v!),
                  ),
                  _buildDropdownField(
                    label: 'Company Valuation:',
                    value: _selectedValuation,
                    items: _valuationOptions,
                    width: 170,
                    onChanged: (v) => setState(() => _selectedValuation = v!),
                  ),
                  _buildDropdownField(
                    label: 'Activity & Comm:',
                    value: _selectedActivityComm,
                    items: _activityOptions,
                    width: 190,
                    onChanged: (v) => setState(() => _selectedActivityComm = v!),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Row 2: Meeting Date Range, Enquiry & Enquiry Type
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _dateFilterEnabled,
                          activeColor: const Color(0xFFF15A24),
                          checkColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFF15A24), width: 1.5),
                          onChanged: (v) => setState(() => _dateFilterEnabled = v ?? false),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('Next Meeting between:', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      const SizedBox(width: 6),
                      _buildSmallTextField(_fromDateCtrl, width: 85),
                      const SizedBox(width: 6),
                      const Text('to', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(width: 6),
                      _buildSmallTextField(_toDateCtrl, width: 85),
                    ],
                  ),
                  _buildDropdownField(
                    label: 'Enquiry:',
                    value: _selectedEnquiry,
                    items: ['All', 'Yes', 'No'],
                    width: 80,
                    onChanged: (v) => setState(() => _selectedEnquiry = v!),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Enquiry Type:', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      const SizedBox(width: 6),
                      _buildSmallTextField(_enquiryTypeCtrl, width: 130),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Row 2b: Location, Web, Rating & Channel Partner Filters
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildDropdownField(
                    label: 'Website:',
                    value: _selectedWebsite,
                    items: ['All', 'Available', 'Not Available'],
                    width: 105,
                    onChanged: (v) => setState(() => _selectedWebsite = v!),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('State:', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      const SizedBox(width: 6),
                      _buildSmallTextField(_stateCtrl, width: 100),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('District:', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      const SizedBox(width: 6),
                      _buildSmallTextField(_districtCtrl, width: 100),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Rating above >', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      const SizedBox(width: 6),
                      _buildSmallTextField(_ratingAboveCtrl, width: 55),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Distributor:', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      const SizedBox(width: 6),
                      _buildSmallTextField(_distributorCtrl, width: 100),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Dealer:', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      const SizedBox(width: 6),
                      _buildSmallTextField(_dealerCtrl, width: 100),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Row 3: Sorting & Execution Controls
              Row(
                children: [
                  _buildDropdownField(
                    label: 'Sort By:',
                    value: _selectedSortBy,
                    items: _sortOptions,
                    width: 190,
                    onChanged: (v) => setState(() => _selectedSortBy = v!),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF15A24),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: _applyFiltersAndSorting,
                    child: const Text('Apply Filter', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF15A24),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: _resetFilters,
                    child: const Text('Reset', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  Text(
                    'Total: ${_filteredRecords.length} / ${_allRecords.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── Results Display Grid (Sorted Company List) ──────────────────────
        const Text(
          'Sorted Company List',
          style: TextStyle(
            color: Color(0xFFF15A24),
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16181C),
            border: Border.all(color: const Color(0xFF2C3038)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1600),
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(const Color(0xFF1E2127)),
                headingRowHeight: 34,
                dataRowMinHeight: 30,
                dataRowMaxHeight: 34,
                horizontalMargin: 12,
                columnSpacing: 16,
                border: TableBorder.all(color: const Color(0xFF282B33), width: 0.8),
                columns: const [
                  DataColumn(label: Text('#', style: _headerStyle)),
                  DataColumn(label: Text('Company Name', style: _headerStyle)),
                  DataColumn(label: Text('Contact Person', style: _headerStyle)),
                  DataColumn(label: Text('Contact Number', style: _headerStyle)),
                  DataColumn(label: Text('Website', style: _headerStyle)),
                  DataColumn(label: Text('State', style: _headerStyle)),
                  DataColumn(label: Text('District', style: _headerStyle)),
                  DataColumn(label: Text('Product & System', style: _headerStyle)),
                  DataColumn(label: Text('Valuation', style: _headerStyle)),
                  DataColumn(label: Text('Rating', style: _headerStyle)),
                  DataColumn(label: Text('Activity', style: _headerStyle)),
                  DataColumn(label: Text('Communication Date', style: _headerStyle)),
                  DataColumn(label: Text('Next Meeting', style: _headerStyle)),
                  DataColumn(label: Text('Enquiry', style: _headerStyle)),
                  DataColumn(label: Text('Enquiry Type', style: _headerStyle)),
                ],
                rows: List.generate(_filteredRecords.length, (idx) {
                  final row = _filteredRecords[idx];
                  final isSelected = _selectedRowIndex == idx;
                  return DataRow(
                    selected: isSelected,
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (isSelected) return const Color(0xFFF15A24);
                      return idx % 2 == 0 ? const Color(0xFF16181C) : const Color(0xFF1A1C22);
                    }),
                    onSelectChanged: (_) {
                      setState(() => _selectedRowIndex = isSelected ? null : idx);
                      if (widget.onOpenCompany != null) {
                        widget.onOpenCompany!(row);
                      }
                    },
                    cells: [
                      DataCell(Text('${idx + 1}', style: _cellStyle)),
                      DataCell(
                        Text(
                          row.companyName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(Text(row.contactPerson, style: _cellStyle)),
                      DataCell(Text(row.contactNumber, style: _cellStyle)),
                      DataCell(Text(row.website, style: _cellStyle)),
                      DataCell(Text(row.state, style: _cellStyle)),
                      DataCell(Text(row.district, style: _cellStyle)),
                      DataCell(Text(row.productsSelected, style: _cellStyle)),
                      DataCell(Text(row.valuation, style: _cellStyle)),
                      DataCell(Text(row.rating.toStringAsFixed(1), style: _cellStyle)),
                      DataCell(Text('${row.activityCount}', style: _cellStyle)),
                      DataCell(Text(row.communicationDate, style: _cellStyle)),
                      DataCell(Text(row.nextMeeting, style: _cellStyle)),
                      DataCell(Text(row.enquiry, style: _cellStyle)),
                      DataCell(Text(row.enquiryType, style: _cellStyle)),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required double width,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        const SizedBox(width: 6),
        Container(
          width: width,
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF131518),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFF383D48)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isDense: true,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E2127),
              style: const TextStyle(color: Colors.white, fontSize: 11.5),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallTextField(TextEditingController ctrl, {required double width}) {
    return SizedBox(
      width: width,
      height: 28,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 11.5),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          filled: true,
          fillColor: const Color(0xFF131518),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: Color(0xFF383D48))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: Color(0xFFF15A24))),
        ),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    color: Colors.white70,
    fontSize: 11,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle _cellStyle = TextStyle(
    color: Colors.white70,
    fontSize: 11,
  );
}
