import '../native_bindings.dart';
import 'widget.dart';
import '../topology_state/fields.dart';
import '../accounts_state/fields.dart';
import '../audit_state/fields.dart';
import '../media_state/fields.dart';
import '../topology_contract/contract.dart';
import '../accounts_contract/contract.dart';
import '../audit_contract/contract.dart';
import '../media_contract/contract.dart';
import '../layout_contract/contract.dart';

abstract class AdminScreenStateContext extends State<AdminScreen>
    with
        WidgetsBindingObserver,
        AdminTopologyFields,
        AdminAccountsFields,
        AdminAuditFields,
        AdminMediaFields
    implements
        AdminTopologyContract,
        AdminAccountsContract,
        AdminAuditContract,
        AdminMediaContract,
        AdminLayoutContract {
  void adminMutateView(VoidCallback action) => setState(action);
}
