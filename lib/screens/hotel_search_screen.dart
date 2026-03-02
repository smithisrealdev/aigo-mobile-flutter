import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/hotel_service.dart';
import '../services/price_alert_service.dart';

class HotelSearchScreen extends StatefulWidget {
  const HotelSearchScreen({super.key});

  @override
  State<HotelSearchScreen> createState() => _HotelSearchScreenState();
}

class _HotelSearchScreenState extends State<HotelSearchScreen> {
  final _destCtrl = TextEditingController();
  DateTime? _checkIn;
  DateTime? _checkOut;
  int _guests = 1;
  int _rooms = 1;

  List<Hotel> _results = [];
  bool _searching = false;
  String? _error;

  Future<void> _search() async {
    if (_destCtrl.text.trim().isEmpty || _checkIn == null || _checkOut == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill in destination, check-in, and check-out')));
      return;
    }
    setState(() { _searching = true; _error = null; _results = []; });
    try {
      final res = await HotelService.instance.searchHotels(SearchHotelsParams(
        cityCode: _destCtrl.text.trim().toUpperCase(),
        checkInDate: _fmtDate(_checkIn!),
        checkOutDate: _fmtDate(_checkOut!),
        adults: _guests,
        roomQuantity: _rooms,
      ));
      if (mounted) setState(() { _results = res; _searching = false; });
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

  Future<void> _pickDate(bool isCheckIn) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isCheckIn ? _checkIn : _checkOut) ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isCheckIn) {
          _checkIn = picked;
        } else {
          _checkOut = picked;
        }
      });
    }
  }

  Future<void> _createPriceAlert(Hotel hotel) async {
    if (_checkIn == null || _checkOut == null) {
      return;
    }
    final alert = await PriceAlertService.instance.createHotelAlert(
      hotelName: hotel.name,
      hotelAddress: hotel.address,
      destination: _destCtrl.text.trim().toUpperCase(),
      checkInDate: _fmtDate(_checkIn!),
      checkOutDate: _fmtDate(_checkOut!),
      rooms: _rooms,
      guests: _guests,
      targetPrice: hotel.price?.total,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(alert != null ? 'Price alert created' : 'Failed to create alert')));
    }
  }

  @override
  void dispose() { _destCtrl.dispose(); super.dispose(); }

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
                  Text('Search Hotels', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
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
                _primaryButton('Search Hotels', Icons.search, _search),
                const SizedBox(height: 20),
                if (_searching) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                if (_error != null) Text(_error!, style: GoogleFonts.dmSans(color: const Color(0xFFEF4444))),
                if (!_searching && _results.isEmpty && _error == null) ...[],
                ..._results.map(_hotelCard),
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
        TextField(
          controller: _destCtrl,
          style: GoogleFonts.dmSans(fontSize: 14),
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'City code (e.g. PAR)',
            hintStyle: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 14),
            prefixIcon: const Icon(Icons.location_city, size: 20, color: AppColors.textSecondary),
            filled: true, fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _dateChip('Check-in', _checkIn, () => _pickDate(true))),
          const SizedBox(width: 12),
          Expanded(child: _dateChip('Check-out', _checkOut, () => _pickDate(false))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _counterField('Guests', _guests, (v) => setState(() => _guests = v))),
          const SizedBox(width: 12),
          Expanded(child: _counterField('Rooms', _rooms, (v) => setState(() => _rooms = v))),
        ]),
      ]),
    );
  }

  Widget _dateChip(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(date != null ? _displayDate(date) : label, style: GoogleFonts.dmSans(fontSize: 13, color: date != null ? AppColors.textPrimary : AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _counterField(String label, int value, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        GestureDetector(onTap: value > 1 ? () => onChanged(value - 1) : null, child: Icon(Icons.remove_circle_outline, size: 20, color: value > 1 ? AppColors.brandBlue : AppColors.textSecondary)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$value', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600))),
        GestureDetector(onTap: () => onChanged(value + 1), child: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.brandBlue)),
      ]),
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

  Widget _hotelCard(Hotel h) {
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
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.hotel, color: AppColors.brandBlue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.name, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600)),
              if (h.city.isNotEmpty) Text(h.city, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
            ])),
          ]),
          const SizedBox(height: 12),
          if (h.address.isNotEmpty)
            Row(children: [
              const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(child: Text(h.address, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          const SizedBox(height: 8),
          Row(children: [
            if (h.rating != null) ...[
              const Icon(Icons.star, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 4),
              Text(h.rating!.toStringAsFixed(1), style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
            ],
            if (h.room != null)
              Text(h.room!.type, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
            const Spacer(),
            if (h.price != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${h.price!.currency} ${h.price!.perNight.toStringAsFixed(0)}', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.brandBlue)),
                Text('/night', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textSecondary)),
              ]),
          ]),
          if (h.cancellation != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.check_circle, size: 14, color: AppColors.success),
              const SizedBox(width: 4),
              Text(h.cancellation!, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.success)),
            ]),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _createPriceAlert(h),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.notifications_none, size: 16, color: AppColors.brandBlue),
                  const SizedBox(width: 4),
                  Text('Price Alert', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
