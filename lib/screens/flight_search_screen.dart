import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/flight_service.dart';
import '../services/saved_search_service.dart';
import '../services/price_alert_service.dart';

class FlightSearchScreen extends StatefulWidget {
  const FlightSearchScreen({super.key});

  @override
  State<FlightSearchScreen> createState() => _FlightSearchScreenState();
}

class _FlightSearchScreenState extends State<FlightSearchScreen> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  DateTime? _departureDate;
  DateTime? _returnDate;
  int _adults = 1;
  String _travelClass = 'ECONOMY';
  final _classes = ['ECONOMY', 'PREMIUM_ECONOMY', 'BUSINESS', 'FIRST'];

  List<Flight> _results = [];
  bool _searching = false;
  String? _error;
  String? _message;

  Future<void> _search() async {
    if (_originCtrl.text.trim().isEmpty || _destCtrl.text.trim().isEmpty || _departureDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill in origin, destination, and departure date')));
      return;
    }
    setState(() { _searching = true; _error = null; _results = []; _message = null; });
    try {
      final res = await FlightService.instance.searchFlights(SearchFlightsParams(
        origin: _originCtrl.text.trim().toUpperCase(),
        destination: _destCtrl.text.trim().toUpperCase(),
        departureDate: _fmtDate(_departureDate!),
        returnDate: _returnDate != null ? _fmtDate(_returnDate!) : null,
        adults: _adults,
        travelClass: _travelClass,
      ));
      if (mounted) setState(() { _results = res.flights; _message = res.message; _searching = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _searching = false; });
    }
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime? d) {
    if (d == null) return 'Select';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}';
  }

  Future<void> _pickDate(bool isDeparture) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isDeparture ? _departureDate : _returnDate) ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isDeparture) {
          _departureDate = picked;
        } else {
          _returnDate = picked;
        }
      });
    }
  }

  Future<void> _saveSearch() async {
    final name = '${_originCtrl.text.trim()} to ${_destCtrl.text.trim()}';
    final saved = await SavedSearchService.instance.saveSearch(
      name: name,
      originCode: _originCtrl.text.trim().toUpperCase(),
      destinationCode: _destCtrl.text.trim().toUpperCase(),
      travelClass: _travelClass,
      adults: _adults,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved != null ? 'Search saved' : 'Failed to save')));
    }
  }

  Future<void> _createPriceAlert() async {
    if (_departureDate == null) {
      return;
    }
    final alert = await PriceAlertService.instance.createFlightAlert(
      originCode: _originCtrl.text.trim().toUpperCase(),
      destinationCode: _destCtrl.text.trim().toUpperCase(),
      departureDate: _fmtDate(_departureDate!),
      returnDate: _returnDate != null ? _fmtDate(_returnDate!) : null,
      adults: _adults,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(alert != null ? 'Price alert created' : 'Failed to create alert')));
    }
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(color: Colors.white),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(children: [
                  GestureDetector(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20)),
                  const SizedBox(width: 12),
                  Text('Search Flights', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSearchForm(),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _primaryButton('Search', Icons.search, _search)),
                  const SizedBox(width: 8),
                  _iconButton(Icons.bookmark_border, _saveSearch),
                  const SizedBox(width: 8),
                  _iconButton(Icons.notifications_none, _createPriceAlert),
                ]),
                const SizedBox(height: 20),
                if (_searching) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                if (_error != null) Text(_error!, style: GoogleFonts.dmSans(color: const Color(0xFFEF4444))),
                if (_message != null && _results.isEmpty) Text(_message!, style: GoogleFonts.dmSans(color: AppColors.textSecondary)),
                ..._results.map(_flightCard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        _inputField(_originCtrl, 'Origin (e.g. BKK)', Icons.flight_takeoff),
        const SizedBox(height: 12),
        _inputField(_destCtrl, 'Destination (e.g. NRT)', Icons.flight_land),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _dateChip('Depart', _departureDate, () => _pickDate(true))),
          const SizedBox(width: 12),
          Expanded(child: _dateChip('Return', _returnDate, () => _pickDate(false))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _dropdownField<int>(
              value: _adults,
              items: List.generate(9, (i) => i + 1),
              label: (v) => '$v Adult${v > 1 ? 's' : ''}',
              onChanged: (v) => setState(() => _adults = v!),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _dropdownField<String>(
              value: _travelClass,
              items: _classes,
              label: (v) => v.replaceAll('_', ' '),
              onChanged: (v) => setState(() => _travelClass = v!),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.dmSans(fontSize: 14),
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _dateChip(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(date != null ? _displayDate(date) : label, style: GoogleFonts.dmSans(fontSize: 13, color: date != null ? AppColors.textPrimary : AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _dropdownField<T>({required T value, required List<T> items, required String Function(T) label, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textPrimary),
          items: items.map((v) => DropdownMenuItem(value: v, child: Text(label(v)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _primaryButton(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: _searching ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: AppColors.brandBlue, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))]),
        child: Icon(icon, color: AppColors.brandBlue, size: 22),
      ),
    );
  }

  Widget _flightCard(Flight f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.flight, color: AppColors.brandBlue, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('${f.outbound.airline} ${f.outbound.flightNumber}', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600))),
            Text('${f.price.currency} ${f.price.total.toStringAsFixed(0)}', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.brandBlue)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.outbound.departureAirport, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(f.outbound.departureTime, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            Column(children: [
              Text(f.outbound.duration, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              SizedBox(width: 80, child: Divider(color: AppColors.brandBlue.withValues(alpha: 0.3))),
              Text(f.outbound.stops == 0 ? 'Direct' : '${f.outbound.stops} stop${f.outbound.stops > 1 ? 's' : ''}',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textSecondary)),
            ]),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(f.outbound.arrivalAirport, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(f.outbound.arrivalTime, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
            ])),
          ]),
          if (f.returnLeg != null) ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.returnLeg!.departureAirport, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(f.returnLeg!.departureTime, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              Column(children: [
                Text(f.returnLeg!.duration, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                SizedBox(width: 80, child: Divider(color: AppColors.brandBlue.withValues(alpha: 0.3))),
                Text(f.returnLeg!.stops == 0 ? 'Direct' : '${f.returnLeg!.stops} stop${f.returnLeg!.stops > 1 ? 's' : ''}',
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textSecondary)),
              ]),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(f.returnLeg!.arrivalAirport, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(f.returnLeg!.arrivalTime, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
              ])),
            ]),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Text(f.bookingClass.replaceAll('_', ' '), style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textSecondary)),
            const Spacer(),
            if (f.seatsAvailable > 0) Text('${f.seatsAvailable} seats left', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFF59E0B))),
          ]),
        ],
      ),
    );
  }
}
