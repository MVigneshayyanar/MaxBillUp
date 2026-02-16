import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';

class BusinessDetailsPage extends StatefulWidget {
  final String uid;
  final String? email;
  final String? displayName;

  const BusinessDetailsPage({
    super.key,
    required this.uid,
    this.email,
    this.displayName,
  });

  @override
  State<BusinessDetailsPage> createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers - matching Profile.dart fields
  final _businessNameCtrl = TextEditingController();
  final _businessPhoneCtrl = TextEditingController();
  final _ownerPhoneCtrl = TextEditingController();
  final _personalPhoneCtrl = TextEditingController();
  final _taxTypeCtrl = TextEditingController();
  final _taxNumberCtrl = TextEditingController();
  final _licenseTypeCtrl = TextEditingController();
  final _licenseNumberCtrl = TextEditingController();
  final _businessLocationCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _businessLocationFocusNode = FocusNode();

  bool _loading = false;
  bool _showAdvancedDetails = false;
  bool _sameAsBusinessNumber = false;
  String _selectedCurrency = 'USD';

  final List<Map<String, String>> _currencies = [
    // Popular currencies first
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},

    // Asia-Pacific
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
    {'code': 'AFN', 'symbol': '؋', 'name': 'Afghan Afghani'},
    {'code': 'AMD', 'symbol': '֏', 'name': 'Armenian Dram'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'AZN', 'symbol': '₼', 'name': 'Azerbaijani Manat'},
    {'code': 'BDT', 'symbol': '৳', 'name': 'Bangladeshi Taka'},
    {'code': 'BHD', 'symbol': '.د.ب', 'name': 'Bahraini Dinar'},
    {'code': 'BND', 'symbol': 'B\$', 'name': 'Brunei Dollar'},
    {'code': 'BTN', 'symbol': 'Nu.', 'name': 'Bhutanese Ngultrum'},
    {'code': 'FJD', 'symbol': 'FJ\$', 'name': 'Fijian Dollar'},
    {'code': 'GEL', 'symbol': '₾', 'name': 'Georgian Lari'},
    {'code': 'HKD', 'symbol': 'HK\$', 'name': 'Hong Kong Dollar'},
    {'code': 'IDR', 'symbol': 'Rp', 'name': 'Indonesian Rupiah'},
    {'code': 'ILS', 'symbol': '₪', 'name': 'Israeli New Shekel'},
    {'code': 'IQD', 'symbol': 'ع.د', 'name': 'Iraqi Dinar'},
    {'code': 'IRR', 'symbol': '﷼', 'name': 'Iranian Rial'},
    {'code': 'JOD', 'symbol': 'د.ا', 'name': 'Jordanian Dinar'},
    {'code': 'KHR', 'symbol': '៛', 'name': 'Cambodian Riel'},
    {'code': 'KRW', 'symbol': '₩', 'name': 'South Korean Won'},
    {'code': 'KWD', 'symbol': 'د.ك', 'name': 'Kuwaiti Dinar'},
    {'code': 'KZT', 'symbol': '₸', 'name': 'Kazakhstani Tenge'},
    {'code': 'LAK', 'symbol': '₭', 'name': 'Lao Kip'},
    {'code': 'LBP', 'symbol': 'ل.ل', 'name': 'Lebanese Pound'},
    {'code': 'LKR', 'symbol': 'Rs', 'name': 'Sri Lankan Rupee'},
    {'code': 'MMK', 'symbol': 'K', 'name': 'Myanmar Kyat'},
    {'code': 'MNT', 'symbol': '₮', 'name': 'Mongolian Tugrik'},
    {'code': 'MOP', 'symbol': 'MOP\$', 'name': 'Macanese Pataca'},
    {'code': 'MVR', 'symbol': 'Rf', 'name': 'Maldivian Rufiyaa'},
    {'code': 'MYR', 'symbol': 'RM', 'name': 'Malaysian Ringgit'},
    {'code': 'NPR', 'symbol': 'Rs', 'name': 'Nepalese Rupee'},
    {'code': 'NZD', 'symbol': 'NZ\$', 'name': 'New Zealand Dollar'},
    {'code': 'OMR', 'symbol': 'ر.ع.', 'name': 'Omani Rial'},
    {'code': 'PHP', 'symbol': '₱', 'name': 'Philippine Peso'},
    {'code': 'PKR', 'symbol': 'Rs', 'name': 'Pakistani Rupee'},
    {'code': 'QAR', 'symbol': 'ر.ق', 'name': 'Qatari Riyal'},
    {'code': 'SAR', 'symbol': '﷼', 'name': 'Saudi Riyal'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
    {'code': 'SYP', 'symbol': '£S', 'name': 'Syrian Pound'},
    {'code': 'THB', 'symbol': '฿', 'name': 'Thai Baht'},
    {'code': 'TJS', 'symbol': 'ЅМ', 'name': 'Tajikistani Somoni'},
    {'code': 'TMT', 'symbol': 'm', 'name': 'Turkmenistani Manat'},
    {'code': 'TRY', 'symbol': '₺', 'name': 'Turkish Lira'},
    {'code': 'TWD', 'symbol': 'NT\$', 'name': 'New Taiwan Dollar'},
    {'code': 'UZS', 'symbol': 'so\'m', 'name': 'Uzbekistani Som'},
    {'code': 'VND', 'symbol': '₫', 'name': 'Vietnamese Dong'},
    {'code': 'YER', 'symbol': '﷼', 'name': 'Yemeni Rial'},

    // Americas
    {'code': 'ARS', 'symbol': '\$', 'name': 'Argentine Peso'},
    {'code': 'AWG', 'symbol': 'ƒ', 'name': 'Aruban Florin'},
    {'code': 'BBD', 'symbol': 'Bds\$', 'name': 'Barbadian Dollar'},
    {'code': 'BMD', 'symbol': 'BD\$', 'name': 'Bermudian Dollar'},
    {'code': 'BOB', 'symbol': 'Bs.', 'name': 'Bolivian Boliviano'},
    {'code': 'BRL', 'symbol': 'R\$', 'name': 'Brazilian Real'},
    {'code': 'BSD', 'symbol': 'B\$', 'name': 'Bahamian Dollar'},
    {'code': 'BZD', 'symbol': 'BZ\$', 'name': 'Belize Dollar'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    {'code': 'CLP', 'symbol': '\$', 'name': 'Chilean Peso'},
    {'code': 'COP', 'symbol': '\$', 'name': 'Colombian Peso'},
    {'code': 'CRC', 'symbol': '₡', 'name': 'Costa Rican Colón'},
    {'code': 'CUP', 'symbol': '\$', 'name': 'Cuban Peso'},
    {'code': 'DOP', 'symbol': 'RD\$', 'name': 'Dominican Peso'},
    {'code': 'GTQ', 'symbol': 'Q', 'name': 'Guatemalan Quetzal'},
    {'code': 'GYD', 'symbol': 'G\$', 'name': 'Guyanese Dollar'},
    {'code': 'HNL', 'symbol': 'L', 'name': 'Honduran Lempira'},
    {'code': 'HTG', 'symbol': 'G', 'name': 'Haitian Gourde'},
    {'code': 'JMD', 'symbol': 'J\$', 'name': 'Jamaican Dollar'},
    {'code': 'KYD', 'symbol': 'CI\$', 'name': 'Cayman Islands Dollar'},
    {'code': 'MXN', 'symbol': '\$', 'name': 'Mexican Peso'},
    {'code': 'NIO', 'symbol': 'C\$', 'name': 'Nicaraguan Córdoba'},
    {'code': 'PAB', 'symbol': 'B/.', 'name': 'Panamanian Balboa'},
    {'code': 'PEN', 'symbol': 'S/.', 'name': 'Peruvian Sol'},
    {'code': 'PYG', 'symbol': '₲', 'name': 'Paraguayan Guaraní'},
    {'code': 'SRD', 'symbol': '\$', 'name': 'Surinamese Dollar'},
    {'code': 'TTD', 'symbol': 'TT\$', 'name': 'Trinidad and Tobago Dollar'},
    {'code': 'UYU', 'symbol': '\$U', 'name': 'Uruguayan Peso'},
    {'code': 'VES', 'symbol': 'Bs.S', 'name': 'Venezuelan Bolívar'},
    {'code': 'XCD', 'symbol': 'EC\$', 'name': 'East Caribbean Dollar'},

    // Europe
    {'code': 'ALL', 'symbol': 'L', 'name': 'Albanian Lek'},
    {'code': 'BAM', 'symbol': 'KM', 'name': 'Bosnia and Herzegovina Mark'},
    {'code': 'BGN', 'symbol': 'лв', 'name': 'Bulgarian Lev'},
    {'code': 'BYN', 'symbol': 'Br', 'name': 'Belarusian Ruble'},
    {'code': 'CHF', 'symbol': 'CHF', 'name': 'Swiss Franc'},
    {'code': 'CZK', 'symbol': 'Kč', 'name': 'Czech Koruna'},
    {'code': 'DKK', 'symbol': 'kr', 'name': 'Danish Krone'},
    {'code': 'GIP', 'symbol': '£', 'name': 'Gibraltar Pound'},
    {'code': 'HRK', 'symbol': 'kn', 'name': 'Croatian Kuna'},
    {'code': 'HUF', 'symbol': 'Ft', 'name': 'Hungarian Forint'},
    {'code': 'ISK', 'symbol': 'kr', 'name': 'Icelandic Króna'},
    {'code': 'MDL', 'symbol': 'L', 'name': 'Moldovan Leu'},
    {'code': 'MKD', 'symbol': 'ден', 'name': 'Macedonian Denar'},
    {'code': 'NOK', 'symbol': 'kr', 'name': 'Norwegian Krone'},
    {'code': 'PLN', 'symbol': 'zł', 'name': 'Polish Złoty'},
    {'code': 'RON', 'symbol': 'lei', 'name': 'Romanian Leu'},
    {'code': 'RSD', 'symbol': 'дин', 'name': 'Serbian Dinar'},
    {'code': 'RUB', 'symbol': '₽', 'name': 'Russian Ruble'},
    {'code': 'SEK', 'symbol': 'kr', 'name': 'Swedish Krona'},
    {'code': 'UAH', 'symbol': '₴', 'name': 'Ukrainian Hryvnia'},

    // Africa
    {'code': 'AOA', 'symbol': 'Kz', 'name': 'Angolan Kwanza'},
    {'code': 'BWP', 'symbol': 'P', 'name': 'Botswana Pula'},
    {'code': 'CDF', 'symbol': 'FC', 'name': 'Congolese Franc'},
    {'code': 'DJF', 'symbol': 'Fdj', 'name': 'Djiboutian Franc'},
    {'code': 'DZD', 'symbol': 'د.ج', 'name': 'Algerian Dinar'},
    {'code': 'EGP', 'symbol': '£', 'name': 'Egyptian Pound'},
    {'code': 'ERN', 'symbol': 'Nfk', 'name': 'Eritrean Nakfa'},
    {'code': 'ETB', 'symbol': 'Br', 'name': 'Ethiopian Birr'},
    {'code': 'GHS', 'symbol': '₵', 'name': 'Ghanaian Cedi'},
    {'code': 'GMD', 'symbol': 'D', 'name': 'Gambian Dalasi'},
    {'code': 'GNF', 'symbol': 'FG', 'name': 'Guinean Franc'},
    {'code': 'KES', 'symbol': 'KSh', 'name': 'Kenyan Shilling'},
    {'code': 'LRD', 'symbol': 'L\$', 'name': 'Liberian Dollar'},
    {'code': 'LSL', 'symbol': 'L', 'name': 'Lesotho Loti'},
    {'code': 'LYD', 'symbol': 'ل.د', 'name': 'Libyan Dinar'},
    {'code': 'MAD', 'symbol': 'د.م.', 'name': 'Moroccan Dirham'},
    {'code': 'MGA', 'symbol': 'Ar', 'name': 'Malagasy Ariary'},
    {'code': 'MRU', 'symbol': 'UM', 'name': 'Mauritanian Ouguiya'},
    {'code': 'MUR', 'symbol': '₨', 'name': 'Mauritian Rupee'},
    {'code': 'MWK', 'symbol': 'MK', 'name': 'Malawian Kwacha'},
    {'code': 'MZN', 'symbol': 'MT', 'name': 'Mozambican Metical'},
    {'code': 'NAD', 'symbol': 'N\$', 'name': 'Namibian Dollar'},
    {'code': 'NGN', 'symbol': '₦', 'name': 'Nigerian Naira'},
    {'code': 'RWF', 'symbol': 'FRw', 'name': 'Rwandan Franc'},
    {'code': 'SCR', 'symbol': '₨', 'name': 'Seychellois Rupee'},
    {'code': 'SDG', 'symbol': 'ج.س.', 'name': 'Sudanese Pound'},
    {'code': 'SLL', 'symbol': 'Le', 'name': 'Sierra Leonean Leone'},
    {'code': 'SOS', 'symbol': 'Sh', 'name': 'Somali Shilling'},
    {'code': 'SSP', 'symbol': '£', 'name': 'South Sudanese Pound'},
    {'code': 'SZL', 'symbol': 'L', 'name': 'Swazi Lilangeni'},
    {'code': 'TND', 'symbol': 'د.ت', 'name': 'Tunisian Dinar'},
    {'code': 'TZS', 'symbol': 'TSh', 'name': 'Tanzanian Shilling'},
    {'code': 'UGX', 'symbol': 'USh', 'name': 'Ugandan Shilling'},
    {'code': 'XAF', 'symbol': 'FCFA', 'name': 'Central African CFA Franc'},
    {'code': 'XOF', 'symbol': 'CFA', 'name': 'West African CFA Franc'},
    {'code': 'ZAR', 'symbol': 'R', 'name': 'South African Rand'},
    {'code': 'ZMW', 'symbol': 'ZK', 'name': 'Zambian Kwacha'},
    {'code': 'ZWL', 'symbol': 'Z\$', 'name': 'Zimbabwean Dollar'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.displayName != null && widget.displayName!.isNotEmpty) {
      _ownerNameCtrl.text = widget.displayName!;
    }

    // Listen to business phone changes to sync with personal phone when checkbox is checked
    _businessPhoneCtrl.addListener(() {
      if (_sameAsBusinessNumber && mounted) {
        _personalPhoneCtrl.text = _businessPhoneCtrl.text;
      }
    });
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _businessPhoneCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _personalPhoneCtrl.dispose();
    _taxTypeCtrl.dispose();
    _taxNumberCtrl.dispose();
    _licenseTypeCtrl.dispose();
    _licenseNumberCtrl.dispose();
    _businessLocationCtrl.dispose();
    _ownerNameCtrl.dispose();
    _businessLocationFocusNode.dispose();
    super.dispose();
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        backgroundColor: isError ? kErrorColor : kPrimaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<int> _getNextStoreId() async {
    final firestore = FirebaseFirestore.instance;
    final querySnapshot = await firestore
        .collection('store')
        .orderBy('storeId', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return 100001;
    }

    final lastStoreId = querySnapshot.docs.first.data()['storeId'] as int? ?? 10000;
    return lastStoreId + 1;
  }

  Future<void> _saveBusinessDetails() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final storeId = await _getNextStoreId();

      // Combine tax type and number into single field
      final taxType = '${_taxTypeCtrl.text.trim()} ${_taxNumberCtrl.text.trim()}'.trim();
      // Combine license type and number into single field
      final licenseNumber = '${_licenseTypeCtrl.text.trim()} ${_licenseNumberCtrl.text.trim()}'.trim();

      final storeData = {
        'storeId': storeId,
        'businessName': _businessNameCtrl.text.trim(),
        'businessPhone': _businessPhoneCtrl.text.trim(),
        'personalPhone': _personalPhoneCtrl.text.trim(),
        'businessLocation': _businessLocationCtrl.text.trim(),
        'gstin':taxType,
        'taxType': taxType,
        'licenseNumber': licenseNumber,
        'currency': _selectedCurrency,
        'ownerName': _ownerNameCtrl.text.trim(),
        'ownerPhone': _ownerPhoneCtrl.text.trim(),
        'ownerEmail': widget.email,
        'ownerUid': widget.uid,
        'plan': 'Free',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore.collection('store').doc(storeId.toString()).set(storeData);

      final userData = {
        'uid': widget.uid,
        'email': widget.email,
        'name': _ownerNameCtrl.text.trim(),
        'storeId': storeId,
        'role': 'owner',
        'isActive': true,
        'isEmailVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore.collection('users').doc(widget.uid).set(userData);

      if (mounted) {
        _showMsg(context.tr('business_registered_success'));
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.email),
          ),
        );
      }
    } catch (e) {
      _showMsg(context.tr('failed_to_save'), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text("Business Profile",
            style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSectionLabel("Business Details"),
                    _buildModernField("Business Name", _businessNameCtrl, HeroIcons.buildingStorefront, isMandatory: true),
                    _buildModernField("Owner Name", _ownerNameCtrl, HeroIcons.user, isMandatory: true),
                    _buildModernField("Business Phone", _businessPhoneCtrl, HeroIcons.phone, type: TextInputType.phone, isMandatory: true, hint: "e.g. +971 501 234 567"),
                    _buildPersonalPhoneField(),
                    _buildModernField("Email Address", TextEditingController(text: widget.email), HeroIcons.envelope, enabled: false),
                    _buildCurrencyField(isMandatory: true),
                    const SizedBox(height: 24),
                    _buildAdvancedDetailsToggle(),
                    if (_showAdvancedDetails) ...[
                      const SizedBox(height: 16),
                      _buildSectionLabel("Address (Optional)"),
                      _buildLocationField(),
                      const SizedBox(height: 24),
                      _buildSectionLabel("Taxation (Optional)"),
                      _buildOptionalField("Tax Type", _taxTypeCtrl, HeroIcons.receiptRefund, hint: "e.g. VAT, GST, Sales Tax"),
                      _buildOptionalField("Tax Number", _taxNumberCtrl, HeroIcons.hashtag, hint: "Enter your tax identification number"),
                      const SizedBox(height: 24),
                      _buildSectionLabel("Additional License (Optional)"),
                      _buildOptionalField("License Type", _licenseTypeCtrl, HeroIcons.identification, hint: "e.g. Trade License, FSSAI, F&B"),
                      _buildOptionalField("License Number", _licenseNumberCtrl, HeroIcons.hashtag, hint: "Enter your license number"),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomActionArea(),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4),
        child: Text(
          text,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0),
        ),
      ),
    );
  }

  Widget _buildModernField(
      String label,
      TextEditingController ctrl,
      HeroIcons icon, {
        bool enabled = true,
        TextInputType type = TextInputType.text,
        bool isMandatory = false,
        String? hint,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: ctrl,
        builder: (context, value, child) {
          final bool isFilled = value.text.isNotEmpty;
          return TextFormField(
            controller: ctrl,
            enabled: enabled,
            keyboardType: type,
            inputFormatters: type == TextInputType.phone
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))]
                : null,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: const TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.normal),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: HeroIcon(icon, color: enabled ? (isFilled ? kPrimaryColor : kBlack54) : kGrey400, size: 18),
              ),
              filled: true,
              fillColor: enabled ? kWhite : kGreyBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isMandatory ? const Color(0xFF6B78D8) : (isFilled ? kPrimaryColor : kGrey200),
                  width: isMandatory ? 1.5 : (isFilled ? 1.5 : 1.0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isMandatory ? const Color(0xFF6B78D8) : kPrimaryColor,
                  width: 2.0,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kGrey200),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kErrorColor),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kErrorColor, width: 2.0),
              ),
              floatingLabelStyle: TextStyle(
                color: isMandatory ? const Color(0xFF6B78D8) : kPrimaryColor,
                fontWeight: FontWeight.w900,
              ),
            ),
            validator: (v) {
              if (isMandatory && (v == null || v.trim().isEmpty)) return "$label is required";
              if (type == TextInputType.phone && v != null && v.trim().isNotEmpty && v.trim().length < 7) {
                return "Enter valid phone number";
              }
              return null;
            },
          );
        },
      ),
    );
  }

  Widget _buildOptionalField(
      String label,
      TextEditingController ctrl,
      HeroIcons icon, {
        bool enabled = true,
        TextInputType type = TextInputType.text,
        String? hint,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: ctrl,
        builder: (context, value, child) {
          final bool isFilled = value.text.isNotEmpty;
          return TextFormField(
            controller: ctrl,
            enabled: enabled,
            keyboardType: type,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w400),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: HeroIcon(icon, color: enabled ? (isFilled ? kPrimaryColor : kBlack54) : kGrey400, size: 18),
              ),
              filled: true,
              fillColor: enabled ? kWhite : kGreyBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: kGrey200,
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kGrey200),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kErrorColor),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kErrorColor, width: 2.0),
              ),
              floatingLabelStyle: const TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPersonalPhoneField() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _personalPhoneCtrl,
            builder: (context, value, child) {
              final bool isFilled = value.text.isNotEmpty;
              return TextFormField(
                controller: _personalPhoneCtrl,
                enabled: !_sameAsBusinessNumber,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
                decoration: InputDecoration(
                  labelText: "Personal Phone",
                  hintText: "e.g. +971 501 234 567",
                  hintStyle: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w400),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: HeroIcon(
                      HeroIcons.phone,
                      color: _sameAsBusinessNumber ? kGrey400 : (isFilled ? kPrimaryColor : kBlack54),
                      size: 18,
                    ),
                  ),
                  filled: true,
                  fillColor: _sameAsBusinessNumber ? kGreyBg : kWhite,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: kGrey200, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kGrey200),
                  ),
                  floatingLabelStyle: const TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            },
          ),
        ),
        InkWell(
          onTap: () {
            setState(() {
              _sameAsBusinessNumber = !_sameAsBusinessNumber;
              if (_sameAsBusinessNumber) {
                _personalPhoneCtrl.text = _businessPhoneCtrl.text;
              }
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _sameAsBusinessNumber ? kPrimaryColor : kGrey400,
                      width: 2,
                    ),
                    color: _sameAsBusinessNumber ? kPrimaryColor : Colors.transparent,
                  ),
                  child: _sameAsBusinessNumber
                      ? const HeroIcon(HeroIcons.check, color: kWhite, size: 14)
                      : null,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Use Business Phone as Personal Number",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kBlack87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAdvancedDetailsToggle() {
    return InkWell(
      onTap: () {
        setState(() {
          _showAdvancedDetails = !_showAdvancedDetails;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGrey200, width: 1.0),
        ),
        child: Row(
          children: [
            HeroIcon(
              _showAdvancedDetails ? HeroIcons.chevronUp : HeroIcons.chevronDown,
              color: kPrimaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _showAdvancedDetails ? "Hide Advanced Details" : "Show Advanced Details (Optional)",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: kPrimaryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (_showAdvancedDetails)
              const HeroIcon(HeroIcons.chevronUp, color: kBlack54, size: 20)
            else
              const HeroIcon(HeroIcons.chevronDown, color: kBlack54, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _businessLocationCtrl,
        builder: (context, value, child) {
          final bool isFilled = value.text.isNotEmpty;
          return TextFormField(
            controller: _businessLocationCtrl,
            keyboardType: TextInputType.streetAddress,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              labelText: "Address",
              hintText: "Enter full business address",
              hintStyle: const TextStyle(
                color: kBlack54,
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: HeroIcon(
                  HeroIcons.mapPin,
                  color: isFilled ? kPrimaryColor : kBlack54,
                  size: 18,
                ),
              ),
              filled: true,
              fillColor: kWhite,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isFilled ? kPrimaryColor : kGrey200,
                  width: isFilled ? 1.5 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: kPrimaryColor,
                  width: 2.0,
                ),
              ),
              floatingLabelStyle: const TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildCurrencyField({bool isMandatory = false}) {
    final sel = _currencies.firstWhere((c) => c['code'] == _selectedCurrency, orElse: () => _currencies[0]);
    final hasValue = _selectedCurrency.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _showCurrencyPicker,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hasValue ? kPrimaryColor : kGrey200, width: hasValue ? 1.5 : 1.0),
          ),
          child: Row(
            children: [
              const HeroIcon(HeroIcons.banknotes, color: kPrimaryColor, size: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Business Currency ${isMandatory ? '*' : ''}",
                      style: const TextStyle(fontSize: 9, color: kBlack54, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${sel['symbol']} ${sel['code']} - ${sel['name']}",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87),
                    ),
                  ],
                ),
              ),
              const HeroIcon(HeroIcons.chevronDown, color: kGrey400),
            ],
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    String searchQuery = ''; // Move searchQuery here
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCurrencies = _currencies.where((currency) {
              if (searchQuery.isEmpty) return true;
              final query = searchQuery.toLowerCase();
              return currency['code']!.toLowerCase().contains(query) ||
                     currency['name']!.toLowerCase().contains(query) ||
                     currency['symbol']!.toLowerCase().contains(query);
            }).toList();

            return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text("Select Currency", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack87, letterSpacing: 0.5)),
                const SizedBox(height: 20),
                // Search Bar
                TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search currency code, name or symbol...',
                    hintStyle: const TextStyle(fontSize: 13, color: kGrey400),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
                    ),
                    filled: true,
                    fillColor: kGreyBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setModalState(() {
                      searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Results count
                if (searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${filteredCurrencies.length} ${filteredCurrencies.length == 1 ? 'currency' : 'currencies'} found',
                        style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                // Currency List
                Expanded(
                  child: filteredCurrencies.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HeroIcon(HeroIcons.magnifyingGlass, size: 48, color: kGrey400),
                              SizedBox(height: 12),
                              Text('No currencies found', style: TextStyle(color: kGrey400, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredCurrencies.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
                          itemBuilder: (context, i) {
                            final c = filteredCurrencies[i];
                            final isSelected = c['code'] == _selectedCurrency;
                            return ListTile(
                              onTap: () {
                                setState(() => _selectedCurrency = c['code']!);
                                Navigator.pop(ctx);
                              },
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected ? kPrimaryColor.withValues(alpha: 0.1) : kGreyBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    c['symbol']!,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? kPrimaryColor : kBlack54,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                c['name']!,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 14,
                                  color: isSelected ? kPrimaryColor : kBlack87,
                                ),
                              ),
                              subtitle: Text(
                                c['code']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? kPrimaryColor : kBlack54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: isSelected
                                  ? const HeroIcon(HeroIcons.checkCircle, color: kPrimaryColor, size: 24)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomActionArea() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: kWhite,
          border: Border(top: BorderSide(color: kGrey200)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _loading ? null : _saveBusinessDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: kWhite))
                : Text(
              "Complete Registration",
              style: const TextStyle(color: kWhite, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0),
            ),
          ),
        ),
      ),
    );
  }
}
