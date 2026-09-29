import 'package:flutter/material.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/async/async_controller.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/core/widgets/app_empty_view.dart';
import 'package:washbinapp/core/widgets/async_view.dart';
import 'package:washbinapp/features/addresses/domain/address.dart';
import 'package:washbinapp/features/addresses/widgets/address_card.dart';

/// Manage saved addresses: add, edit, delete, choose the default.
///
/// Separate from the picker in the booking flow — this one changes the address
/// book, that one only reads it.
class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  AsyncController<List<Address>>? _addresses;
  String? _busyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_addresses != null) {
      return;
    }
    final repository = AppServicesScope.of(context).addresses;
    _addresses = AsyncController(repository.getMyAddresses)..load();
  }

  @override
  void dispose() {
    _addresses?.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final saved = await Navigator.of(context).push(AppRouter.addressForm());
    if (saved != null) {
      await _addresses?.refresh();
    }
  }

  Future<void> _edit(Address address) async {
    final saved = await Navigator.of(context)
        .push(AppRouter.addressForm(existing: address));
    if (saved != null) {
      await _addresses?.refresh();
    }
  }

  Future<void> _setDefault(Address address) async {
    await _mutate(address, (repository) => repository.setDefault(address.id));
  }

  Future<void> _delete(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this address?'),
        content: Text(address.oneLine),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await _mutate(
        address,
        (repository) => repository.deleteAddress(address.id),
      );
    }
  }

  /// Runs a write against one row, showing a spinner on it and surfacing any
  /// refusal — deleting a default promotes another, so the list is reread.
  Future<void> _mutate(
    Address address,
    Future<void> Function(dynamic repository) action,
  ) async {
    final repository = AppServicesScope.of(context).addresses;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyId = address.id);

    try {
      await action(repository);
      await _addresses?.refresh();
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _addresses!;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: AppTheme.red,
        foregroundColor: Colors.white,
        title: const Text(
          'Saved addresses',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.red,
          onRefresh: controller.refresh,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return AsyncView<List<Address>>(
                state: controller.state,
                onRetry: controller.load,
                loadingLabel: 'Loading addresses',
                isEmpty: (addresses) => addresses.isEmpty,
                empty: AppEmptyView(
                  title: 'No addresses yet',
                  message: 'Save one so booking takes a tap instead of a form.',
                  icon: Icons.location_off_rounded,
                  action: FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add an address'),
                  ),
                ),
                builder: (context, addresses) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: addresses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    return AddressCard(
                      address: address,
                      isBusy: _busyId == address.id,
                      onTap: () => _edit(address),
                      trailing: _RowMenu(
                        address: address,
                        onEdit: () => _edit(address),
                        onSetDefault: () => _setDefault(address),
                        onDelete: () => _delete(address),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppTheme.red,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add address',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.address,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: AppTheme.muted),
      onSelected: (action) => switch (action) {
        'edit' => onEdit(),
        'default' => onSetDefault(),
        'delete' => onDelete(),
        _ => null,
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        // Absent for the current default: the API has no way to clear one, and
        // offering it would only produce a refusal.
        if (!address.isDefault)
          const PopupMenuItem(value: 'default', child: Text('Set as default')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}
