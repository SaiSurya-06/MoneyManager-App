import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/account.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common/toast_notification.dart';
import 'account_form_preview.dart';

class AccountForm extends ConsumerStatefulWidget {
  final Account? account;

  const AccountForm({super.key, this.account});

  @override
  ConsumerState<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late TextEditingController _limitController;
  late TextEditingController _billingStartController;
  late TextEditingController _statementDueController;
  late TextEditingController _minimumDueController;
  late String _selectedType;
  late String _selectedIcon;
  late String _selectedColor;

  final List<String> _types = ['Bank', 'Cash', 'Credit Card', 'Savings', 'Investment'];
  
  final List<Map<String, String>> _icons = [
    {'name': 'Bank', 'key': 'account_balance'},
    {'name': 'Cash', 'key': 'payments'},
    {'name': 'Card', 'key': 'credit_card'},
    {'name': 'Savings', 'key': 'savings'},
    {'name': 'Investment', 'key': 'trending_up'},
  ];

  final List<Map<String, String>> _colors = [
    {'name': 'Emerald', 'hex': '#00A86B'},
    {'name': 'Red', 'hex': '#E53935'},
    {'name': 'Sapphire', 'hex': '#1E88E5'},
    {'name': 'Purple', 'hex': '#8E24AA'},
    {'name': 'Orange', 'hex': '#FB8C00'},
    {'name': 'Gold', 'hex': '#D4AF37'},
    {'name': 'Rose Gold', 'hex': '#B76E79'},
    {'name': 'Charcoal', 'hex': '#36454F'},
    {'name': 'Midnight Blue', 'hex': '#191970'},
    {'name': 'Orchid', 'hex': '#DA70D6'},
  ];

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    _nameController = TextEditingController(text: acc?.name ?? '');
    _balanceController = TextEditingController(text: acc?.balance.toString() ?? '0.0');
    _limitController = TextEditingController(text: acc?.limitAmount?.toString() ?? '');
    _billingStartController = TextEditingController(text: acc?.billingCycleStartDay?.toString() ?? '');
    _statementDueController = TextEditingController(text: acc?.statementDueDay?.toString() ?? '');
    _minimumDueController = TextEditingController(text: acc?.minimumDue?.toString() ?? '');
    _selectedType = acc?.type ?? 'Bank';
    _selectedIcon = acc?.icon ?? 'account_balance';
    _selectedColor = acc?.color ?? '#1E88E5';

    _nameController.addListener(() => setState(() {}));
    _balanceController.addListener(() => setState(() {}));
    _limitController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _limitController.dispose();
    _billingStartController.dispose();
    _statementDueController.dispose();
    _minimumDueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final balance = double.tryParse(_balanceController.text) ?? 0.0;
    final limit = _selectedType == 'Credit Card' ? (double.tryParse(_limitController.text) ?? 0.0) : null;
    final billingStart = _selectedType == 'Credit Card' ? int.tryParse(_billingStartController.text) : null;
    final statementDue = _selectedType == 'Credit Card' ? int.tryParse(_statementDueController.text) : null;
    final minimumDue = _selectedType == 'Credit Card' ? double.tryParse(_minimumDueController.text) : null;
    
    bool success;
    if (widget.account == null) {
      // Create new account
      final newId = await ref.read(accountsProvider.notifier).addAccount(
            name,
            _selectedType,
            balance,
            _selectedIcon,
            _selectedColor,
            true,
            limit,
            billingStart,
            statementDue,
            minimumDue,
          );
      success = newId != null;
    } else {
      // Update existing account
      final updated = widget.account!.copyWith(
        name: name,
        type: _selectedType,
        balance: balance,
        icon: _selectedIcon,
        color: _selectedColor,
        limitAmount: limit,
        billingCycleStartDay: billingStart,
        statementDueDay: statementDue,
        minimumDue: minimumDue,
      );
      success = await ref.read(accountsProvider.notifier).updateAccount(
        updated,
        updateBalance: updated.balanceMinorUnits != widget.account!.balanceMinorUnits,
      );
    }

    if (success && mounted) {
      ToastNotification.show(
        context,
        widget.account == null ? 'Account created successfully!' : 'Account updated successfully!',
      );
      Navigator.pop(context);
    }
  }

  Future<void> _toggleArchive() async {
    final acc = widget.account!;
    final accId = acc.id!;
    if (acc.isArchived) {
      final success = await ref.read(accountsProvider.notifier).restoreAccount(accId);
      if (success && mounted) {
        ToastNotification.show(context, 'Account restored successfully.');
        Navigator.pop(context);
      }
    } else {
      final success = await ref.read(accountsProvider.notifier).archiveAccount(accId);
      if (success && mounted) {
        ToastNotification.show(context, 'Account archived. It is now hidden from active selection.');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _delete() async {
    final accId = widget.account!.id!;
    final txCount = await ref.read(accountsProvider.notifier).getTransactionCount(accId);

    if (txCount > 0) {
      if (!mounted) return;
      final shouldArchive = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Account Has Transactions'),
          content: Text(
            'This account has $txCount recorded transaction(s). To protect your financial history and ensure reporting integrity, it cannot be permanently deleted.\n\n'
            'Would you like to archive this account instead? Archiving preserves all historical records while hiding the account from daily transactions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archive Account'),
            ),
          ],
        ),
      );

      if (shouldArchive == true && mounted) {
        final success = await ref.read(accountsProvider.notifier).archiveAccount(accId);
        if (success && mounted) {
          ToastNotification.show(context, 'Account archived successfully.');
          Navigator.pop(context);
        }
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This account has 0 transactions. Are you sure you want to permanently delete it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(accountsProvider.notifier).deleteAccount(accId);
      if (success && mounted) {
        ToastNotification.show(context, 'Account deleted.');
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(authProvider).profile?.preferredCurrency ?? 'USD';

    // Mock an account for live preview
    final previewAccount = Account(
      id: widget.account?.id,
      name: _nameController.text.trim().isEmpty ? 'Account Preview' : _nameController.text.trim(),
      type: _selectedType,
      balance: double.tryParse(_balanceController.text) ?? 0.0,
      icon: _selectedIcon,
      color: _selectedColor,
      isShared: true,
      createdAt: widget.account?.createdAt ?? DateTime.now(),
      limitAmount: double.tryParse(_limitController.text),
      isArchived: widget.account?.isArchived ?? false,
      billingCycleStartDay: int.tryParse(_billingStartController.text),
      statementDueDay: int.tryParse(_statementDueController.text),
      minimumDue: double.tryParse(_minimumDueController.text),
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141420) : const Color(0xFFF8F9FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                widget.account == null ? 'Create New Account' : 'Edit Account',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Dynamic Card Preview
              AccountFormPreview(account: previewAccount, currency: currency),
              const SizedBox(height: 20),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Account Name',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter an account name';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Initial / Current Balance Field
              TextFormField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _selectedType == 'Credit Card' ? 'Outstanding Balance (negative for debt)' : 'Current Balance',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter a balance';
                  if (double.tryParse(val) == null) return 'Please enter a valid number';
                  return null;
                },
              ),

              if (_selectedType == 'Credit Card') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _limitController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Total Credit Limit',
                    prefixIcon: Icon(Icons.credit_score_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Please enter a credit limit';
                    if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Please enter a valid limit';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _billingStartController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cycle Start Day (1-31)',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        validator: (val) {
                          if (val != null && val.isNotEmpty) {
                            final day = int.tryParse(val);
                            if (day == null || day < 1 || day > 31) return '1 - 31';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _statementDueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Payment Due Day (1-31)',
                          prefixIcon: Icon(Icons.event_outlined),
                        ),
                        validator: (val) {
                          if (val != null && val.isNotEmpty) {
                            final day = int.tryParse(val);
                            if (day == null || day < 1 || day > 31) return '1 - 31';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _minimumDueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Minimum Amount Due (optional)',
                    prefixIcon: Icon(Icons.price_check_outlined),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Account Type dropdown
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Account Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                items: _types.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedType = val;
                      
                      // Auto-select icon match type
                      if (val == 'Bank') _selectedIcon = 'account_balance';
                      if (val == 'Cash') _selectedIcon = 'payments';
                      if (val == 'Credit Card') _selectedIcon = 'credit_card';
                      if (val == 'Savings') _selectedIcon = 'savings';
                      if (val == 'Investment') _selectedIcon = 'trending_up';
                    });
                  }
                },
              ),

              const SizedBox(height: 20),

              // Color Selection Row
              const Text(
                'Color Tag',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colors.length,
                  itemBuilder: (context, index) {
                    final item = _colors[index];
                    final hexStr = '0xFF${item["hex"]!.replaceAll("#", "")}';
                    final color = Color(int.parse(hexStr));
                    final isSelected = _selectedColor == item['hex'];

                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = item['hex']!),
                      child: Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: isDark ? Colors.white : Colors.black, width: 3)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Icon Selection Row
              const Text(
                'Card Icon',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _icons.length,
                  itemBuilder: (context, index) {
                    final item = _icons[index];
                    final key = item['key']!;
                    final isSelected = _selectedIcon == key;

                    IconData iconData;
                    if (key == 'account_balance') {
                      iconData = Icons.account_balance;
                    } else if (key == 'payments') {
                      iconData = Icons.payments;
                    } else if (key == 'credit_card') {
                      iconData = Icons.credit_card;
                    } else if (key == 'savings') {
                      iconData = Icons.savings;
                    } else {
                      iconData = Icons.trending_up;
                    }

                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = key),
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFFE53935).withValues(alpha: 0.15) 
                              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: const Color(0xFFE53935), width: 2)
                              : null,
                        ),
                        child: Icon(
                          iconData,
                          color: isSelected ? const Color(0xFFE53935) : Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Save Action Button
              ElevatedButton(
                onPressed: _save,
                child: Text(widget.account == null ? 'Create Account' : 'Save Changes'),
              ),

              if (widget.account != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD4AF37),
                    side: const BorderSide(color: Color(0xFFD4AF37)),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _toggleArchive,
                  icon: Icon(widget.account!.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
                  label: Text(
                    widget.account!.isArchived ? 'Restore Account' : 'Archive Account',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                    side: const BorderSide(color: Color(0xFFE53935)),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
