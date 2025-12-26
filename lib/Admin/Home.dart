import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/services/direct_notification_service.dart';
import 'package:maxbillup/Auth/LoginPage.dart';

// --- Modern Design Tokens ---
const Color kBrandPrimary = Color(0xFF2F7CF6); // Indigo
const Color kBrandSecondary = Color(0xFF2F7CF6);
const Color kBgColor = Color(0xFFF8FAFC);
const Color kCardColor = Colors.white;
const Color kTextDark = Color(0xFF1E293B);
const Color kTextMuted = Color(0xFF64748B);

class HomePage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const HomePage({super.key, required this.uid, this.userEmail});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text('Admin Console',
            style: TextStyle(color: kTextDark, fontWeight: FontWeight.w800, fontSize: 22)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 20),
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  debugPrint('Logout error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
                    );
                  }
                }
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: kBrandPrimary,
                boxShadow: [
                  BoxShadow(
                    color: kBrandPrimary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: kTextMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.store_rounded, size: 18), SizedBox(width: 8), Text('Stores')])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.auto_awesome_rounded, size: 18), SizedBox(width: 8), Text('Knowledge')])),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StoresTab(adminEmail: widget.userEmail),
          const KnowledgeTab(),
        ],
      ),
    );
  }
}

// ==========================================
// STORES TAB
// ==========================================
class StoresTab extends StatelessWidget {
  final String? adminEmail;
  const StoresTab({super.key, this.adminEmail});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('store').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kBrandPrimary));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(Icons.store_outlined, 'No stores registered yet.');
        }

        final stores = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stores.length,
          itemBuilder: (context, index) {
            final store = stores[index];
            final data = store.data() as Map<String, dynamic>;
            final businessName = data['businessName'] ?? 'Unknown Store';
            final ownerName = data['ownerName'] ?? 'N/A';
            final plan = data['plan'] ?? 'Free';
            final isActive = data['isActive'] ?? true;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StoreDetailPage(storeId: store.id, storeData: data))),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 48, width: 48,
                            decoration: BoxDecoration(color: kBrandPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Text(businessName[0].toUpperCase(), style: const TextStyle(color: kBrandPrimary, fontWeight: FontWeight.bold, fontSize: 20))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(businessName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark)),
                                const SizedBox(height: 2),
                                Text(ownerName, style: const TextStyle(fontSize: 13, color: kTextMuted)),
                              ],
                            ),
                          ),
                          _buildPlanBadge(plan),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatusIndicator(isActive),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kTextMuted),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlanBadge(String plan) {
    bool isMax = plan.toLowerCase() == 'Pro';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMax ? Colors.amber.shade50 : Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(plan.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isMax ? Colors.amber.shade800 : Colors.blueGrey.shade700)),
    );
  }

  Widget _buildStatusIndicator(bool active) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: active ? Colors.green : Colors.red, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(active ? 'Active' : 'Deactivated',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.green.shade700 : Colors.red.shade700)),
      ],
    );
  }
}

// ==========================================
// KNOWLEDGE TAB
// ==========================================
class KnowledgeTab extends StatelessWidget {
  const KnowledgeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('knowledge').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kBrandPrimary));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(Icons.lightbulb_outline, 'Knowledge base is empty.');
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final data = posts[index].data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(data['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, color: kTextDark)),
                  subtitle: Text(data['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTextMuted, fontSize: 13)),
                  trailing: const Icon(Icons.edit_note_rounded, color: kBrandPrimary),
                  onTap: () => _showKnowledgeDialog(context, docId: posts[index].id, data: data),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showKnowledgeDialog(context),
        backgroundColor: kBrandPrimary,
        elevation: 4,
        label: const Text('Post Knowledge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _showKnowledgeDialog(BuildContext context, {String? docId, Map<String, dynamic>? data}) {
    final titleController = TextEditingController(text: data?['title']);
    final contentController = TextEditingController(text: data?['content']);
    String category = data?['category'] ?? 'General';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(docId == null ? 'New Post' : 'Edit Post', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: ['General', 'Tutorial', 'Updates', 'Tips'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => category = v!,
              ),
              const SizedBox(height: 16),
              TextField(controller: contentController, maxLines: 4, decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          if (docId != null)
            TextButton(child: const Text('Delete', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('knowledge').doc(docId).delete();
                  Navigator.pop(context);
                }),
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBrandPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final titleText = titleController.text.trim();
              final contentText = contentController.text.trim();

              if (titleText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a title')),
                );
                return;
              }

              final payload = {
                'title': titleText,
                'content': contentText,
                'category': category,
                'updatedAt': FieldValue.serverTimestamp(),
              };

              try {
                if (docId == null) {
                  // Creating new post
                  payload['createdAt'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance.collection('knowledge').add(payload);

                  // Send notification to all users
                  // Using Firestore method - works with Cloud Functions
                  await DirectNotificationService().sendKnowledgeNotificationViaFirestore(
                    title: titleText,
                    content: contentText,
                    category: category,
                  );

                  // Alternative: Direct FCM API (requires valid server key)
                  // await DirectNotificationService().sendKnowledgeNotificationDirect(
                  //   title: titleText,
                  //   content: contentText,
                  //   category: category,
                  // );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Knowledge posted & notifications sent!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  // Updating existing post
                  await FirebaseFirestore.instance.collection('knowledge').doc(docId).update(payload);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Knowledge updated successfully!'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                }

                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                debugPrint('Error saving knowledge: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(docId == null ? 'Post' : 'Save', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// STORE DETAIL PAGE
// ==========================================
class StoreDetailPage extends StatelessWidget {
  final String storeId;
  final Map<String, dynamic> storeData;

  const StoreDetailPage({super.key, required this.storeId, required this.storeData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: Text(storeData['businessName'] ?? 'Store Details', style: const TextStyle(color: kTextDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: kTextDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status/Revenue Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kBrandPrimary, kBrandSecondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: kBrandPrimary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderChip(storeData['plan'] ?? 'Free'),
                      _buildHeaderChip(storeData['isActive'] == true ? 'Active' : 'Inactive', isStatus: true),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Revenue Insight (Preview)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  const Text('\$ 0.00', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats Grid
            Row(
              children: [
                Expanded(child: _buildRealTimeStat(storeId, 'Products', 'Products', Icons.inventory_2_rounded, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildRealTimeStat(storeId, 'Sales', 'sales', Icons.receipt_long_rounded, Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _buildRealTimeStat(storeId, 'Customers', 'customers', Icons.people_alt_rounded, Colors.orange)),
              ],
            ),
            const SizedBox(height: 24),

            // Detail Card
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
              child: Column(
                children: [
                  _detailTile(Icons.person_rounded, 'Owner', storeData['ownerName']),
                  _detailTile(Icons.alternate_email_rounded, 'Email', storeData['ownerEmail']),
                  _detailTile(Icons.phone_iphone_rounded, 'Phone', storeData['ownerPhone'] ?? storeData['businessPhone']),
                  _detailTile(Icons.pin_drop_rounded, 'Location', storeData['businessLocation']),
                  _detailTile(Icons.description_rounded, 'GSTIN', storeData['gstIn']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderChip(String label, {bool isStatus = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Text(label.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildRealTimeStat(String sId, String label, String collection, IconData icon, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('store').doc(sId).collection(collection).snapshots(),
      builder: (context, snapshot) {
        String count = snapshot.hasData ? '${snapshot.data!.docs.length}' : '...';
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
          child: Column(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
              const SizedBox(height: 12),
              Text(count, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: kTextDark)),
              Text(label, style: const TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Widget _detailTile(IconData icon, String label, String? value) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kBgColor, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: kBrandPrimary, size: 20)),
      title: Text(label, style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.bold)),
      subtitle: Text(value ?? 'N/A', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
    );
  }
}

Widget _buildEmptyState(IconData icon, String msg) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(msg, style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600, fontSize: 16)),
      ],
    ),
  );
}