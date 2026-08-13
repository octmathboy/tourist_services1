import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class AddServiceScreen extends StatefulWidget {
  const AddServiceScreen({Key? key}) : super(key: key);

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _costController = TextEditingController();

  String _selectedCategory = 'hotel'; // القيمة الافتراضية
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  bool _isFree = false;

  // دالة التقاط موقع الجوال عبر الـ GPS
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // التحقق من صلاحيات الموقع
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديد الموقع بنجاح!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحديد الموقع: $e')),
      );
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  // دالة حفظ البيانات في Firebase Firestore
  Future<void> _saveService() async {
    if (_nameController.text.isEmpty || _latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء كافة البيانات وتحديد الموقع!')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('services').add({
      'name': _nameController.text,
      'phone': _phoneController.text,
      'category': _selectedCategory,
      'cost_details': _isFree ? 'مجاني' : _costController.text,
      'is_free': _isFree,
      'lat': _latitude,
      'lng': _longitude,
      'created_at': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إضافة الخدمة بنجاح!')),
    );
    _nameController.clear();
    _phoneController.clear();
    _costController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة خدمة / مكان جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // اختيار التصنيف
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: const [
                DropdownMenuItem(value: 'hotel', child: Text('فندق / إقامة')),
                DropdownMenuItem(value: 'restaurant', child: Text('مطعم / كافيه')),
                DropdownMenuItem(value: 'taxi', child: Text('سائق تاكسي / نقل')),
                DropdownMenuItem(value: 'guide', child: Text('مرشد سياحي')),
                DropdownMenuItem(value: 'place', child: Text('مكان سياحي')),
              ],
              onChanged: (val) => setState(() => _selectedCategory = val!),
              decoration: const InputDecoration(labelText: 'نوع الخدمة'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم المكان / الخدمة'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'رقم الهاتف / الواتساب'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            // خيار مجاني أو مدفوع
            CheckboxListTile(
              title: const Text('هل الدخول / الخدمة مجانية؟'),
              value: _isFree,
              onChanged: (val) => setState(() => _isFree = val!),
            ),

            if (!_isFree)
              TextField(
                controller: _costController,
                decoration: const InputDecoration(
                  labelText: 'تفاصيل السعر (مثلاً: 4000 دج / ليلة)',
                ),
              ),
            const SizedBox(height: 20),

            // زر الحصول على موقع GPS
            ElevatedButton.icon(
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              icon: const Icon(Icons.my_location),
              label: Text(_isLoadingLocation
                  ? 'جاري تحديد الموقع...'
                  : (_latitude == null ? 'تحديد موعي الحالي (GPS)' : 'تم التقاط الموقع ✓')),
            ),
            const SizedBox(height: 20),

            // زر حفظ الخدمة
            ElevatedButton(
              onPressed: _saveService,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('نشر الخدمة الان'),
            ),
          ],
        ),
      ),
    );
  }
}