import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:wr_manager/daily_report.dart';
import 'package:wr_manager/employee_credits.dart';
import 'package:wr_manager/employee_history.dart';
import 'package:wr_manager/employee_list.dart';
import 'package:wr_manager/item_preview.dart';
import 'package:wr_manager/login.dart';
import 'package:wr_manager/model/wr_session.dart';
import 'package:wr_manager/quantity_prompt.dart';
import 'package:wr_manager/sale_history.dart';
import 'package:wr_manager/ui/wr_alerts.dart';

import 'model/app_config.dart';

class WarehousePage extends StatefulWidget {
  const WarehousePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePage> {
  var employeeObject = {
    'id': 0,
    'userName': '',
    'departmentName': '',
  };

  final txtCardNo = TextEditingController();
  final txtEmployeeName = TextEditingController();
  final txtDepartmentName = TextEditingController();
  final txtSearch = TextEditingController();
  late FocusNode focusNodeOfCardNo;
  bool isLoggedByCard = false;
  bool employeeSelection = false;

  @override
  void initState() {
    super.initState();
    _bindCategories();

    focusNodeOfCardNo = FocusNode();

    try {
      WrSession session = WrSession();
      isLoggedByCard = session.isLoggedByCard;
      if (session.readCardNo != null && session.readCardNo.length > 0) {
        txtCardNo.text = session.readCardNo;
        session.readCardNo = '';

        _readCard();
      }
    } catch (e) {}

    try {
      AppConfig configManager = AppConfig();
      var configObj = configManager.getConfigObject();
      if (configObj['employeeSelection'] != null) {
        employeeSelection = configObj['employeeSelection'];
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    focusNodeOfCardNo.dispose();
    super.dispose();
  }

  var warehouseId = 0;
  var isEmployeeSelected = false;
  var receiptProcessing = false;

  var lastCardReadDate = DateTime.now();
  var cardTimeOutIsRunning = false;

  var lastFilterReadDate = DateTime.now();
  var filterTimeOutIsRunning = false;

  var isDataLoading = false;

  var itemDetails = <dynamic>[
    // {itemId: 1, 'itemName': 'Eldiven', 'quantity': 5},
    // {'itemName': 'Gözlük', 'quantity': 2},
    // {'itemName': 'Kulaklık', 'quantity': 3},
  ];

  var employeeCredits = <dynamic>[];

  var _lastItemIndex = -1;

  var itemCategories = <dynamic>[];
  var itemGroups = <dynamic>[];
  var items = <dynamic>[];
  var filteredItems = <dynamic>[];

  var selectedCategory = null;
  var selectedGroup = null;
  var selectedItem = null;

  var stateFlag = false;

  // 0: contains, 1: starts with, 2: ends with
  var searchQueryType = 0;
  var searchQuery = '';
  var makeSearch = false;

  // 0: categories, 1: groups, 2: items
  var itemViewType = 0;

  void _closeApp() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) =>
              const LoginPage(title: 'MetaGanos Depo Yönetimi')),
    );
  }

  String _getRowData(int index, String field) {
    return itemDetails[index][field].toString();
  }

  void _removeRow(int index) {
    setState(() {
      itemDetails.removeAt(index);
    });
  }

  void _decreaseQuantity(int index) {
    setState(() {
      var rowData = itemDetails.elementAt(index);
      if (rowData != null) {
        if (rowData['quantity'] == 1) {
          _removeRow(index);
        } else if (rowData['quantity'] > 1) {
          rowData['quantity']--;
        }
      }
    });
  }

  String _getItemRowData(int index, String field) {
    return filteredItems[index][field].toString();
  }

  Uint8List getBytesOfItemImage(int index) {
    // Image example. Put your data string
    if (filteredItems[index]['itemImage'] != null &&
        filteredItems[index]['itemImage'].toString().length > 0) {
      String base64Image = filteredItems[index]['itemImage'].toString();

      final UriData? data = Uri.parse(base64Image).data;

      Uint8List? myImage = data?.contentAsBytes();
      return myImage ?? Uint8List(0);
    }

    return Uint8List(0);
  }

  void _showQuantityDialog(int itemIndex) {
    _lastItemIndex = itemIndex;
    showQuantityPrompt(context, _onQuantityEntered);
  }

  void _onQuantityEntered(value) {
    if (_lastItemIndex > -1 && int.tryParse(value) != null) {
      _appendItem(_lastItemIndex, int.parse(value));
      _lastItemIndex = -1;
    }
  }

  void _appendItem(int itemIndex, [int quantity = 1]) {
    if (employeeObject == null || employeeObject['id'] == 0) {
      showWrAlert(context, 'Uyarı', 'Önce personel kartı okutulmalıdır.');
      return;
    }

    if (employeeCredits == null || employeeCredits.length == 0) {
      showWrAlert(
          context, 'Uyarı', 'Personelin yeterli bakiyesi bulunmamaktadır.');
      return;
    }

    var itemRow = filteredItems[itemIndex];

    var existingCredit = employeeCredits.firstWhere(
        (d) =>
            (d['itemId'] == null &&
                d['itemGroupId'] == null &&
                d['itemCategoryId'] == itemRow['itemCategoryId']) ||
            (d['itemId'] == null &&
                d['itemGroupId'] == itemRow['itemGroupId']) ||
            (d['itemId'] == itemRow['id']),
        orElse: () => null);

    var existingItem = itemDetails
        .firstWhere((d) => d['itemId'] == itemRow['id'], orElse: () => null);

    var usedCredit = 0;
    if (existingItem != null) {
      usedCredit = existingItem['quantity'];
    }

    if (existingCredit == null ||
        (existingCredit['rangeCredit'] - usedCredit - quantity + 1) <= 0) {
      showWrAlert(
          context, 'Uyarı', 'Bu ürün için yeterli bakiyeniz bulunmamaktadır.');
      return;
    }

    setState(() {
      if (existingItem != null) {
        existingItem['quantity'] = existingItem['quantity'] + quantity;
      } else {
        itemDetails.add({
          'itemName': itemRow['itemName'].toString(),
          'itemId': itemRow['id'],
          'itemGroupId': itemRow['itemGroupId'],
          'itemCategoryId': itemRow['itemCategoryId'],
          'quantity': quantity,
        });
      }
    });
  }

  int _getTotalQuantity() {
    late int totalQty = 0;

    if (itemDetails.isNotEmpty) {
      totalQty = itemDetails.map((d) => d['quantity']).reduce((a, b) => a + b);
    }

    return totalQty;
  }

  void _cancelReceipt() {
    employeeObject['id'] = 0;
    employeeObject['userName'] = '';
    employeeObject['departmentName'] = '';
    txtCardNo.text = '';
    txtEmployeeName.text = '';
    txtDepartmentName.text = '';

    _clearEmployeeInfo();

    setState(() {
      isEmployeeSelected = false;
      itemDetails = [];
    });

    txtSearch.text = '';
    _runFilter();
  }

  void _applyReceipt() async {
    if (receiptProcessing == true) return;

    receiptProcessing = true;
    try {
      if (itemDetails.isEmpty) {
        throw ('Önce listeye stok eklemelisiniz.');
      }

      if (int.parse(employeeObject['id'].toString()) <= 0) {
        throw ('Önce personel seçmelisiniz.');
      }

      AppConfig configManager = AppConfig();
      WrSession session = WrSession();
      var configObj = configManager.getConfigObject();

      var errorItems = [];
      var errMsg = '';

      for (var row in itemDetails) {
        final postResult = await post(
            configObj['serverAddr'] +
                'Warehouse/${session.plantId}/DeliverProduct',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.apiToken}',
            },
            body: jsonEncode({
              'employeeId': employeeObject['id'],
              'itemId': row['itemId'],
              'quantity': row['quantity'],
              'warehouseCode': configObj['warehouseCode'],
            }));

        if (postResult.statusCode == 200) {
          var postBody = jsonDecode(postResult.body);
          if (!postBody['result']) {
            errMsg = postBody['errorMessage'];
            errorItems.add(row);
          }
        } else if (postResult.statusCode == 401) {
          errMsg = 'Bu işlem için yetkiniz bulunmamaktadır.';
          errorItems.add(row);
        } else {
          errMsg = jsonDecode(postResult.body)['errorMessage'];
          errorItems.add(row);
        }
      }

      setState(() {
        itemDetails = errorItems;
      });

      if (!errMsg.isEmpty) {
        throw (errMsg.toString());
      } else {
        await showWrAlert(
            context, 'Bilgilendirme', 'İşlem başarıyla gerçekleşti.');
        txtSearch.text = '';
        _runFilter();
      }

      _clearEmployeeInfo();
    } catch (e) {
      showWrAlert(context, 'Uyarı', e.toString());
    }

    receiptProcessing = false;
  }

  void _showEmployeeDialog() async {
    try {
      AppConfig configManager = AppConfig();
      WrSession session = WrSession();
      var configObj = configManager.getConfigObject();
      final getResult =
          await get(configObj['serverAddr'] + 'Employee', headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.apiToken}',
      });

      if (getResult.statusCode == 200) {
        var itemList = jsonDecode(getResult.body);
        showEmployeeList(context, itemList, onEmployeeSelectedOnList);
      }
    } catch (e) {}
  }

  void _refreshState() {
    setState(() {
      stateFlag = !stateFlag;
    });
  }

  void onEmployeeSelectedOnList(dynamic employeeParam) async {
    if (employeeParam != null) {
      employeeObject['userName'] = employeeParam['employeeName'];
      employeeObject['id'] = employeeParam['id'];
      employeeObject['departmentName'] = employeeParam['departmentName'];

      txtEmployeeName.text = employeeObject['userName'].toString();
      txtDepartmentName.text = employeeObject['departmentName'].toString();
      txtCardNo.text = '';

      setState(() {
        isEmployeeSelected = true;
      });

      AppConfig configManager = AppConfig();
      var configObj = configManager.getConfigObject();
      WrSession session = WrSession();

      final creditResult = await get(
          configObj['serverAddr'] + 'Employee/${employeeObject['id']}/Credits',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.apiToken}',
          });

      if (creditResult.statusCode == 200) {
        final creditBody = jsonDecode(creditResult.body);
        setState(() {
          employeeCredits = creditBody;
        });
      }

      _bindCategories();
    }
  }

  void _showEmployeeHistory() async {
    try {
      var stDate = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(Duration(days: -365)));
      var enDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      AppConfig configManager = AppConfig();
      WrSession session = WrSession();
      var configObj = configManager.getConfigObject();
      final getResult =
          await post(configObj['serverAddr'] + 'Warehouse/ConsumeReport',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${session.apiToken}',
              },
              body: jsonEncode({
                'warehouseCode': configObj['warehouseCode'],
                'plantCode': configObj['plantCode'],
                'startDate': '${stDate}T00:00:00',
                'endDate': '${enDate}T23:59:00',
                'employeeId': [employeeObject['id']],
              }));

      if (getResult.statusCode == 200) {
        var itemList = jsonDecode(getResult.body);
        itemList.sort((a, b) => b['consumedDate']
            .toString()
            .compareTo(a['consumedDate'].toString()));
        showEmployeeHistory(context, itemList);
      }
    } catch (e) {
      log(e.toString());
    }
  }

  void _showEmployeeCredits() async {
    try {
      AppConfig configManager = AppConfig();
      WrSession session = WrSession();
      var configObj = configManager.getConfigObject();
      final getResult = await get(
          configObj['serverAddr'] + 'Employee/${employeeObject['id']}/Credits',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.apiToken}',
          });
      if (getResult.statusCode == 200) {
        var itemList = jsonDecode(getResult.body);
        await showEmployeeCredits(context, itemList);
      }
    } catch (e) {}
  }

  void _showDailyReport() async {
    try {
      var fDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      AppConfig configManager = AppConfig();
      WrSession session = WrSession();
      var configObj = configManager.getConfigObject();
      final getResult =
          await post(configObj['serverAddr'] + 'Warehouse/ConsumeReport',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${session.apiToken}',
              },
              body: jsonEncode({
                'warehouseCode': configObj['warehouseCode'],
                'plantCode': configObj['plantCode'],
                'startDate': '${fDate}T00:00:00',
                'endDate': '${fDate}T23:59:00',
              }));

      if (getResult.statusCode == 200) {
        var itemList = jsonDecode(getResult.body);
        showDailyReport(context, itemList);
      }
    } catch (e) {}
  }

  void _showTotalHistory() {
    var stDate = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().add(const Duration(days: -7)));
    var enDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    Future.delayed(Duration(milliseconds: 200),
        () => _bindSaleHistoryData(stDate, enDate));
  }

  void _bindSaleHistoryData(String stDate, String enDate) async {
    try {
      AppConfig configManager = AppConfig();
      WrSession session = WrSession();
      var configObj = configManager.getConfigObject();
      final getResult =
          await post(configObj['serverAddr'] + 'Warehouse/ConsumeReport',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${session.apiToken}',
              },
              body: jsonEncode({
                'warehouseCode': configObj['warehouseCode'],
                'plantCode': configObj['plantCode'],
                'startDate': '${stDate}T00:00:00',
                'endDate': '${enDate}T23:59:00',
              }));

      if (getResult.statusCode == 200) {
        var itemList = jsonDecode(getResult.body);
        showSaleHistory(
            context, itemList, stDate, enDate, _onHistoryFilterChanged);
      }
    } catch (e) {}
  }

  void _onHistoryFilterChanged(String startDate, String endDate) async {
    Future.delayed(Duration(milliseconds: 200),
        () => _bindSaleHistoryData(startDate, endDate));
  }

  void _clearEmployeeInfo() {
    employeeObject['id'] = 0;
    employeeObject['userName'] = '';
    employeeObject['departmentName'] = '';
    txtCardNo.text = '';
    txtEmployeeName.text = '';
    txtDepartmentName.text = '';
    employeeCredits = [];

    setState(() {
      isEmployeeSelected = false;
    });
  }

  void _readCard() async {
    setState(() {
      isDataLoading = true;
    });

    var cardNo = txtCardNo.text;
    AppConfig configManager = AppConfig();
    var configObj = configManager.getConfigObject();
    final loginResult = await post(configObj['serverAddr'] + 'User/LoginCard',
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'login': cardNo,
          'dealerCode': configObj['dealerCode'],
          'plantCode': configObj['plantCode'],
          'password': ''
        }));

    if (loginResult.statusCode == 200 &&
        jsonDecode(loginResult.body)['result'] == true) {
      final loginBody = jsonDecode(loginResult.body);
      employeeObject['userName'] = loginBody['employee']['employeeName'];
      employeeObject['id'] = loginBody['employee']['id'];
      employeeObject['departmentName'] =
          loginBody['employee']['departmentName'];

      WrSession session = WrSession();
      session.apiToken = loginBody['token'];
      session.plantId = loginBody['employee']['plantId'];

      txtEmployeeName.text = employeeObject['userName'].toString();
      txtDepartmentName.text = employeeObject['departmentName'].toString();
      txtCardNo.text = '';

      final creditResult = await get(
          configObj['serverAddr'] + 'Employee/${employeeObject['id']}/Credits',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.apiToken}',
          });

      if (creditResult.statusCode == 200) {
        final creditBody = jsonDecode(creditResult.body);
        setState(() {
          employeeCredits = creditBody;
        });
      }

      setState(() {
        isEmployeeSelected = true;
      });
    } else {
      isEmployeeSelected = false;
      employeeObject['id'] = 0;
      employeeObject['userName'] = '';
      employeeObject['departmentName'] = '';
      txtEmployeeName.text = '';
      txtDepartmentName.text = '';
      txtCardNo.text = '';

      setState(() {
        employeeCredits = [];
        isEmployeeSelected = false;
      });

      if (cardNo.isNotEmpty) {
        var snackBar = SnackBar(
          content: Text('OKUTULAN KART BİLGİLERİ GEÇERSİZ.'),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    }
    setState(() {
      isDataLoading = false;
    });

    _bindCategories();
  }

  void _checkCardTimes() {
    var dtNow = DateTime.now();
    var diff = dtNow.difference(lastCardReadDate).inMilliseconds;
    if (diff >= 750 && diff >= 0) {
      _readCard();
    }
  }

  Future<void> _checkCardTimeout() async {
    if (cardTimeOutIsRunning == true) {
      return;
    }
    cardTimeOutIsRunning = true;
    Future.delayed(const Duration(milliseconds: 750), () => _checkCardTimes());
    cardTimeOutIsRunning = false;
  }

  void _runFilter() async {
    try {
      makeSearch = true;
      _bindItems();
    } catch (e) {}
  }

  void _checkFilters() {
    var dtNow = DateTime.now();
    var diff = dtNow.difference(lastFilterReadDate).inMilliseconds;
    if (diff >= 750 && diff >= 0) {
      _runFilter();
    }
  }

  Future<void> _checkFilterTimeout() async {
    if (filterTimeOutIsRunning == true) {
      return;
    }

    filterTimeOutIsRunning = true;
    Future.delayed(const Duration(milliseconds: 750), () => _checkFilters());
    filterTimeOutIsRunning = false;
  }

  void _goBackForSearch() {
    if (itemViewType > 0) {
      itemViewType--;

      if (itemViewType == 1 && selectedGroup == null) itemViewType = 0;
    }

    if (itemViewType == 0)
      _bindCategories();
    else if (itemViewType == 1)
      _bindGroups();
    else if (itemViewType == 2) _bindItems();
  }

  void _bindCategories() async {
    setState(() {
      isDataLoading = true;
    });

    try {
      AppConfig configManager = AppConfig();
      WrSession session = WrSession();
      var configObj = configManager.getConfigObject();

      final wrResult = await get(
          configObj['serverAddr'] +
              'Warehouse/GetByCode/${session.plantId}?wrCode=${configObj['warehouseCode']}',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.apiToken}',
          });
      if (wrResult.statusCode != 200) return;
      final warehouseModel = jsonDecode(wrResult.body);
      warehouseId = warehouseModel['id'];

      final getResult = await get(
          configObj['serverAddr'] +
              'ItemCategory/GetForWarehouse/${warehouseId}',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.apiToken}',
          });
      if (getResult.statusCode == 200) {
        var catList = jsonDecode(getResult.body);

        // filter by employeeCredit
        if (employeeObject['id'] != 0) {
          catList = catList
              .where((d) =>
                  employeeCredits.any((c) => c['itemCategoryId'] == d['id']))
              .toList();
        }

        setState(() {
          itemCategories = catList;
        });
      }
    } catch (e) {}

    setState(() {
      isDataLoading = false;
    });
  }

  Uint8List getBytesOfCategoryImage(int index) {
    // Image example. Put your data string
    if (itemCategories[index]['categoryImage'] != null &&
        itemCategories[index]['categoryImage'].toString().length > 0) {
      String base64Image = itemCategories[index]['categoryImage'].toString();

      final UriData? data = Uri.parse(base64Image).data;

      Uint8List? myImage = data?.contentAsBytes();
      return myImage ?? Uint8List(0);
    }

    return Uint8List(0);
  }

  Uint8List getBytesOfGroupImage(int index) {
    // Image example. Put your data string
    if (itemGroups[index]['groupImage'] != null &&
        itemGroups[index]['groupImage'].toString().length > 0) {
      String base64Image = itemGroups[index]['groupImage'].toString();

      final UriData? data = Uri.parse(base64Image).data;

      Uint8List? myImage = data?.contentAsBytes();
      return myImage ?? Uint8List(0);
    }

    return Uint8List(0);
  }

  void _bindGroups() async {
    setState(() {
      isDataLoading = true;
    });

    try {
      if (selectedCategory != null) {
        AppConfig configManager = AppConfig();
        WrSession session = WrSession();
        var configObj = configManager.getConfigObject();
        final getResult = await get(
            configObj['serverAddr'] +
                'ItemCategory/${selectedCategory['id']}/GroupsForWarehouse/$warehouseId',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.apiToken}',
            });

        if (getResult.statusCode == 200) {
          var grList = jsonDecode(getResult.body);

          // filter by employeeCredit
          if (employeeObject['id'] != 0) {
            grList = grList
                .where((d) => employeeCredits.any((c) =>
                    c['itemCategoryId'] == d['itemCategoryId'] &&
                    (c['itemGroupId'] == null || c['itemGroupId'] == d['id'])))
                .toList();
          }

          setState(() {
            itemGroups = grList;
            itemViewType = 1;
          });
        }
      } else {
        setState(() {
          itemGroups = [];
          itemViewType = 1;
        });
      }
    } catch (e) {}

    setState(() {
      isDataLoading = false;
    });
  }

  String getCreditText(creditItem) {
    var rangeText = '';
    switch (creditItem['rangeType']) {
      case 1:
        rangeText = 'Günlük';
        break;
      case 2:
        rangeText = 'Haftalık';
        break;
      case 3:
        rangeText = 'Aylık';
        break;
      case 4:
        rangeText = 'Sınırsız';
        break;
      default:
        break;
    }

    if (creditItem['rangeLength'] > 1)
      rangeText = creditItem['rangeLength'].toString() + ' ' + rangeText;

    return (creditItem['itemName'].length > 0
            ? creditItem['itemName']
            : creditItem['itemGroupName'].length > 0
                ? creditItem['itemGroupName']
                : creditItem['itemCategoryName'].length > 0
                    ? creditItem['itemCategoryName']
                    : '') +
        ', ' +
        rangeText +
        ': ' +
        creditItem['rangeCredit'].toString() +
        ' ADET';
  }

  void _bindItems() async {
    setState(() {
      isDataLoading = true;
    });

    try {
      if ((selectedGroup != null && itemViewType == 1) || makeSearch) {
        AppConfig configManager = AppConfig();
        WrSession session = WrSession();
        var configObj = configManager.getConfigObject();

        if (!makeSearch) {
          final getResult = await get(
              configObj['serverAddr'] +
                  'ItemGroup/ItemsForWarehouse/${selectedGroup['id']}/$warehouseId',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${session.apiToken}',
              });

          if (getResult.statusCode == 200) {
            var itemList = jsonDecode(getResult.body);

            // filter by employeeCredit
            if (employeeObject['id'] != 0) {
              itemList = itemList
                  .where((d) => employeeCredits.any((c) =>
                      c['itemCategoryId'] == d['itemCategoryId'] &&
                      (c['itemGroupId'] == null ||
                          c['itemGroupId'] == d['itemGroupId']) &&
                      (c['itemId'] == null || c['itemId'] == d['id'])))
                  .toList();
            }

            setState(() {
              filteredItems = itemList;
              items = itemList;
              itemViewType = 2;
            });
          }
        } else {
          makeSearch = false;

          if (txtSearch.text.isEmpty) {
            setState(() {
              itemViewType = 0;
            });
          } else {
            var employeeId = employeeObject['id'];
            final getResult = await get(
                configObj['serverAddr'] +
                    'Item/SearchForWarehouse/$warehouseId/$employeeId/' +
                    txtSearch.text,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer ${session.apiToken}',
                });

            if (getResult.statusCode == 200) {
              var itemList = jsonDecode(getResult.body);

              setState(() {
                filteredItems = itemList;
                items = itemList;
                itemViewType = 2;

                if (filteredItems.length > 0) {
                  var firstItem = filteredItems[0];
                  if (firstItem['barcode1'] == txtSearch.text ||
                      firstItem['barcode2'] == txtSearch.text) {
                    _appendItem(itemList.indexOf(firstItem));
                    txtSearch.text = '';
                    _runFilter();
                  }
                }
              });
            }
          }
        }
      }
    } catch (e) {}

    setState(() {
      isDataLoading = false;
    });
  }

  void _showItemImage(int itemIndex) async {
    try {
      AppConfig configManager = AppConfig();
      WrSession session = WrSession();
      var configObj = configManager.getConfigObject();

      var sItem = filteredItems[itemIndex];

      final getResult =
          await get(configObj['serverAddr'] + 'Item/${sItem['id']}', headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.apiToken}',
      });

      if (getResult.statusCode == 200) {
        var itemData = jsonDecode(getResult.body);
        if (itemData['itemImage'] == null ||
            itemData['itemImage'].toString().isEmpty) {
          showWrAlert(context, 'Uyarı', 'Bu stok için resim yüklenmemiş.');
        } else {
          showItemPreview(context, itemData['itemImage'].toString());
        }
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    // WidgetsBinding.instance.addPostFrameCallback(_onLoad);

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Image.asset(
              'image/asset/appicon.png',
              height: 60,
              fit: BoxFit.fitHeight,
            ),
          ),
          const Text('Depo Yönetimi'),
        ]),
        centerTitle: true,
        actions: <Widget>[
          Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () {},
                child: ElevatedButton(
                  onPressed: _closeApp,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Çıkış Yap'),
                      Padding(
                        padding: EdgeInsets.only(left: 5),
                        child: Icon(
                          Icons.logout,
                          size: 26.0,
                        ),
                      )
                    ],
                  ),
                ),
              )),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                  width: !(employeeSelection == true &&
                                          isLoggedByCard == false)
                                      ? MediaQuery.of(context).size.width *
                                              0.4 -
                                          20
                                      : MediaQuery.of(context).size.width *
                                              0.3 -
                                          20,
                                  child: RawKeyboardListener(
                                    focusNode: focusNodeOfCardNo,
                                    child: TextFormField(
                                      obscureText: true,
                                      controller: txtCardNo,
                                      decoration: const InputDecoration(
                                        border: UnderlineInputBorder(),
                                        labelText:
                                            'PERSONEL KARTINI BURAYA OKUTUNUZ',
                                      ),
                                    ),
                                    onKey: (RawKeyEvent event) {
                                      if (event.runtimeType == RawKeyUpEvent) {
                                        lastCardReadDate = DateTime.now();
                                        _checkCardTimeout();
                                      }
                                    },
                                  )),
                              if (employeeSelection == true &&
                                  isLoggedByCard == false)
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.1 -
                                          10,
                                  height: 45,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 5),
                                    child: ElevatedButton(
                                      onPressed: _showEmployeeDialog,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Text('SEÇ'),
                                          Padding(
                                            padding: EdgeInsets.only(left: 5),
                                            child: Icon(
                                              Icons.search,
                                              size: 26.0,
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 1),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Row(children: [
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                              0.1 -
                                          60,
                                      child: const Text('Personel Adı',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                    ),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                              0.1 -
                                          10,
                                      child: Padding(
                                          padding:
                                              EdgeInsets.only(left: 5, top: 5),
                                          child: TextField(
                                            controller: txtEmployeeName,
                                            readOnly: true,
                                            cursorColor: Colors.white,
                                            style: TextStyle(fontSize: 12),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.all(12),
                                            ),
                                          )),
                                    ),
                                  ]),
                                  Row(children: [
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                              0.1 -
                                          60,
                                      child: const Text('Departman',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                    ),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                              0.1 -
                                          10,
                                      child: Padding(
                                          padding: EdgeInsets.only(left: 5),
                                          child: TextField(
                                            controller: txtDepartmentName,
                                            readOnly: true,
                                            cursorColor: Colors.white,
                                            style: TextStyle(fontSize: 12),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.all(12),
                                            ),
                                          )),
                                    ),
                                  ])
                                ],
                              ),
                              if (isEmployeeSelected)
                                SizedBox(
                                  width: 120,
                                  height: 80,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        left: 20, top: 5, bottom: 5),
                                    child: ElevatedButton(
                                      style: ButtonStyle(
                                          backgroundColor:
                                              MaterialStateProperty.all(
                                                  Colors.black54),
                                          foregroundColor:
                                              MaterialStateProperty.all(
                                                  Colors.white70)),
                                      onPressed: _showEmployeeCredits,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Text('BAKİYE'),
                                          Padding(
                                            padding: EdgeInsets.only(left: 5),
                                            child: Icon(
                                              Icons.credit_score,
                                              size: 26.0,
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (isEmployeeSelected)
                                SizedBox(
                                  width: 110,
                                  height: 80,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        left: 5, top: 5, bottom: 5),
                                    child: ElevatedButton(
                                      style: ButtonStyle(
                                          backgroundColor:
                                              MaterialStateProperty.all(
                                                  Colors.black54),
                                          foregroundColor:
                                              MaterialStateProperty.all(
                                                  Colors.white70)),
                                      onPressed: _showEmployeeHistory,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Text('GEÇMİŞ'),
                                          Padding(
                                            padding: EdgeInsets.only(left: 5),
                                            child: Icon(
                                              Icons.history,
                                              size: 26.0,
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (isEmployeeSelected)
                                SizedBox(
                                  width: 110,
                                  height: 80,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        left: 5, top: 5, bottom: 5),
                                    child: ElevatedButton(
                                      style: ButtonStyle(
                                          backgroundColor:
                                              MaterialStateProperty.all(
                                                  Colors.black54),
                                          foregroundColor:
                                              MaterialStateProperty.all(
                                                  Colors.white70)),
                                      onPressed: () => {
                                        _clearEmployeeInfo(),
                                      },
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Text('TEMİZLE'),
                                          Padding(
                                            padding: EdgeInsets.only(left: 5),
                                            child: Icon(
                                              Icons.arrow_back,
                                              size: 26.0,
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                            padding: const EdgeInsets.only(
                                left: 5, top: 5, bottom: 5),
                            child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.3,
                                child: Container(
                                  alignment: Alignment.topLeft,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.deepOrangeAccent),
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(5)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.3,
                                        color: Colors.deepOrangeAccent,
                                        height: 25,
                                        child: const Text(
                                          'Güncel Haklar',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                          textAlign: TextAlign.center,
                                          textScaleFactor: 1.10,
                                        ),
                                      ),
                                      SizedBox(
                                          width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.3 -
                                              20,
                                          height: 100,
                                          child: GridView.count(
                                            primary: false,
                                            padding: const EdgeInsets.all(5),
                                            crossAxisSpacing: 1,
                                            mainAxisSpacing: 1,
                                            crossAxisCount: 2,
                                            childAspectRatio: 7,
                                            children: List<SizedBox>.generate(
                                              employeeCredits.length,
                                              (creditIndex) => SizedBox(
                                                  child: Text(
                                                '■ ' +
                                                    getCreditText(
                                                        employeeCredits[
                                                            creditIndex]),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.normal),
                                                textAlign: TextAlign.left,
                                                textScaleFactor: 0.85,
                                              )),
                                            ),
                                          ))
                                    ],
                                  ),
                                ))),
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 5, top: 5, bottom: 5),
                          child: OutlinedButton(
                            style: ButtonStyle(
                                shape: MaterialStateProperty.all(
                                    RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(5.0))),
                                side: MaterialStateProperty.all(
                                    const BorderSide(
                                        color: Colors.deepOrange,
                                        width: 1,
                                        style: BorderStyle.solid))),
                            onPressed: _showEmployeeCredits,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('BAKİYE LİSTESİ'),
                                Padding(
                                  padding: EdgeInsets.only(left: 5),
                                  child: Icon(
                                    Icons.credit_score,
                                    size: 26.0,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 5, top: 5, bottom: 5),
                          child: OutlinedButton(
                            style: ButtonStyle(
                                shape: MaterialStateProperty.all(
                                    RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(5.0))),
                                side: MaterialStateProperty.all(
                                    const BorderSide(
                                        color: Colors.deepOrange,
                                        width: 1,
                                        style: BorderStyle.solid))),
                            onPressed: _showTotalHistory,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('GEÇMİŞ ALIMLAR'),
                                Padding(
                                  padding: EdgeInsets.only(left: 5),
                                  child: Icon(
                                    Icons.history,
                                    size: 26.0,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 5, top: 5, bottom: 5, right: 5),
                          child: OutlinedButton(
                            style: ButtonStyle(
                                shape: MaterialStateProperty.all(
                                    RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(5.0))),
                                side: MaterialStateProperty.all(
                                    const BorderSide(
                                        color: Colors.deepOrange,
                                        width: 1,
                                        style: BorderStyle.solid))),
                            onPressed: _showDailyReport,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('GÜNLÜK RAPOR'),
                                Padding(
                                  padding: EdgeInsets.only(left: 5),
                                  child: Icon(
                                    Icons.report,
                                    size: 26.0,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height - 210,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                      width: MediaQuery.of(context).size.width * 0.4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.4,
                            height: MediaQuery.of(context).size.height - 350,
                            child: SingleChildScrollView(
                              child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('STOK')),
                                    DataColumn(label: Text('ADET')),
                                    DataColumn(label: Text('#')),
                                  ],
                                  rows: List<DataRow>.generate(
                                    itemDetails.length,
                                    (int index) => DataRow(
                                      color: MaterialStateProperty.resolveWith<
                                          Color?>((Set<MaterialState> states) {
                                        // All rows will have the same selected color.
                                        if (states
                                            .contains(MaterialState.selected)) {
                                          return Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.08);
                                        }
                                        // Even rows will have a grey color.
                                        if (index.isEven) {
                                          return Colors.grey.withOpacity(0.3);
                                        }
                                        return null; // Use default value for other states and odd rows.
                                      }),
                                      cells: <DataCell>[
                                        DataCell(Text(
                                          _getRowData(index, 'itemName'),
                                        )),
                                        DataCell(Text(
                                            _getRowData(index, 'quantity'),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold))),
                                        DataCell(
                                          Row(
                                            children: [
                                              OutlinedButton(
                                                style: ButtonStyle(
                                                    shape: MaterialStateProperty
                                                        .all(RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        5.0))),
                                                    side: MaterialStateProperty
                                                        .all(const BorderSide(
                                                            color: Colors.red,
                                                            width: 1,
                                                            style: BorderStyle
                                                                .solid))),
                                                onPressed: () =>
                                                    _decreaseQuantity(index),
                                                child: const Icon(
                                                  Icons.vertical_align_bottom,
                                                  size: 26.0,
                                                ),
                                              ),
                                              OutlinedButton(
                                                style: ButtonStyle(
                                                    shape: MaterialStateProperty
                                                        .all(RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        5.0))),
                                                    side: MaterialStateProperty
                                                        .all(const BorderSide(
                                                            color: Colors.red,
                                                            width: 1,
                                                            style: BorderStyle
                                                                .solid))),
                                                onPressed: () =>
                                                    _removeRow(index),
                                                child: const Icon(
                                                  Icons.delete,
                                                  size: 26.0,
                                                ),
                                              )
                                            ],
                                          ),
                                        )
                                      ],
                                      onSelectChanged: (bool? value) {
                                        setState(() {
                                          // selected[index] = value!;
                                        });
                                      },
                                    ),
                                  ),
                                  dividerThickness: 0,
                                  dataRowHeight: 40,
                                  showCheckboxColumn: false,
                                  showBottomBorder: true,
                                  dataTextStyle: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                  headingTextStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                  headingRowColor:
                                      MaterialStateProperty.resolveWith(
                                          (states) => Colors.deepOrangeAccent)),
                            ),
                          ),
                          SizedBox(
                              height: 100,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Container(
                                      color: Colors.black87,
                                      width: MediaQuery.of(context).size.width *
                                          0.4,
                                      height: 40,
                                      child: Padding(
                                        padding: const EdgeInsets.all(5),
                                        child: Text(
                                            'TOPLAM: ${_getTotalQuantity()} ADET',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold)),
                                      )),
                                  Container(
                                    color: Colors.deepOrangeAccent,
                                    width:
                                        MediaQuery.of(context).size.width * 0.4,
                                    height: 60,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (itemDetails.length > 0)
                                          SizedBox(
                                            width: 200,
                                            height: 60,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 5,
                                                  top: 5,
                                                  bottom: 5,
                                                  right: 5),
                                              child: ElevatedButton(
                                                style: ButtonStyle(
                                                    backgroundColor:
                                                        MaterialStateProperty
                                                            .all(
                                                                Colors.black54),
                                                    foregroundColor:
                                                        MaterialStateProperty
                                                            .all(Colors
                                                                .white70)),
                                                onPressed: () => {
                                                  showWrConfirm(
                                                      context,
                                                      'Uyarı',
                                                      'Bu listeyi iptal etmek istediğinizden emin misiniz?',
                                                      _cancelReceipt)
                                                },
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: const [
                                                    Text('İPTAL ET',
                                                        style: TextStyle(
                                                            fontSize: 22)),
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                          left: 5),
                                                      child: Icon(
                                                        Icons.cancel,
                                                        size: 26.0,
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        SizedBox(
                                          width: 200,
                                          height: 60,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                left: 5,
                                                top: 5,
                                                bottom: 5,
                                                right: 5),
                                            child: ElevatedButton(
                                              style: ButtonStyle(
                                                  backgroundColor:
                                                      MaterialStateProperty.all(
                                                          Colors.black54),
                                                  foregroundColor:
                                                      MaterialStateProperty.all(
                                                          Colors.white70)),
                                              onPressed: () => {
                                                Future.delayed(
                                                    const Duration(
                                                        milliseconds: 200),
                                                    _applyReceipt)
                                              },
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Text('ONAYLA',
                                                      style: TextStyle(
                                                          fontSize: 22)),
                                                  Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 5),
                                                    child: Icon(
                                                      Icons.check_circle,
                                                      size: 26.0,
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              )),
                        ],
                      )),
                  Column(
                    children: [
                      /* SEARCH BOX AND BACK BUTTONS */
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(5),
                              child: SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.3 -
                                          10,
                                  child: RawKeyboardListener(
                                    focusNode: FocusNode(),
                                    child: TextFormField(
                                      controller: txtSearch,
                                      decoration: const InputDecoration(
                                        border: UnderlineInputBorder(),
                                        labelText: 'ARAMA / ÜRÜN BARKODU',
                                      ),
                                    ),
                                    onKey: (RawKeyEvent event) {
                                      if (event.runtimeType == RawKeyUpEvent) {
                                        lastFilterReadDate = DateTime.now();
                                        _checkFilterTimeout();
                                      }
                                    },
                                  )),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(5),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.1 -
                                    10,
                                height: 45,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: ElevatedButton(
                                    onPressed: () => {
                                      txtSearch.text = '',
                                      _runFilter(),
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Text('TEMİZLE'),
                                        Padding(
                                          padding: EdgeInsets.only(left: 5),
                                          child: Icon(
                                            Icons.delete,
                                            size: 26.0,
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (itemViewType > 0)
                              Padding(
                                padding: const EdgeInsets.all(5),
                                child: SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.1 -
                                          10,
                                  height: 45,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 5),
                                    child: ElevatedButton(
                                      onPressed: _goBackForSearch,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Text('GERİ'),
                                          Padding(
                                            padding: EdgeInsets.only(left: 5),
                                            child: Icon(
                                              Icons.arrow_back,
                                              size: 26.0,
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!isDataLoading &&
                          (itemViewType == 0 || itemViewType == 1))
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: MediaQuery.of(context).size.height - 275,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 5, left: 5),
                            child: Container(
                                alignment: Alignment.topLeft,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.deepOrangeAccent),
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(5)),
                                ),
                                child: Padding(
                                    padding: const EdgeInsets.all(5),
                                    child:

                                        /* SELECTION PLACES */
                                        SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.6,
                                      height:
                                          MediaQuery.of(context).size.height -
                                              300,
                                      child: /* CATEGORY | GROUP VIEW */
                                          GridView.count(
                                        primary: false,
                                        padding: const EdgeInsets.all(5),
                                        crossAxisSpacing: 5,
                                        mainAxisSpacing: 5,
                                        crossAxisCount: 4,
                                        children:
                                            List<GestureDetector>.generate(
                                          itemViewType == 0
                                              ? itemCategories.length
                                              : itemGroups.length,
                                          (index) => GestureDetector(
                                              onTap: () {
                                                if (itemViewType == 0) {
                                                  selectedCategory =
                                                      itemCategories[index];
                                                  _bindGroups();
                                                } else if (itemViewType == 1) {
                                                  selectedGroup =
                                                      itemGroups[index];
                                                  _bindItems();
                                                }
                                              },
                                              child: Container(
                                                  width: (MediaQuery.of(context)
                                                                      .size
                                                                      .width *
                                                                  0.6 -
                                                              10) /
                                                          4 -
                                                      10,
                                                  height: 175,
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: Colors.grey),
                                                    borderRadius:
                                                        const BorderRadius.all(
                                                            Radius.circular(5)),
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    children: [
                                                      Container(
                                                          width: (MediaQuery.of(context)
                                                                              .size
                                                                              .width *
                                                                          0.6 -
                                                                      10) /
                                                                  4 -
                                                              10,
                                                          height: 50,
                                                          decoration:
                                                              const BoxDecoration(
                                                            color:
                                                                Colors.black54,
                                                            border: Border(
                                                                bottom: BorderSide(
                                                                    color: Colors
                                                                        .grey,
                                                                    width: 1)),
                                                          ),
                                                          child: Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                      top: 15),
                                                              child: Text(
                                                                  '${itemViewType == 0 ? itemCategories[index]['itemCategoryName'] : itemGroups[index]['itemGroupName']}',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          18)))),
                                                      if ((itemViewType == 0 &&
                                                              itemCategories[index][
                                                                      'categoryImage'] !=
                                                                  null &&
                                                              itemCategories[index]['categoryImage']
                                                                      .toString()
                                                                      .length >
                                                                  0) ||
                                                          (itemViewType == 1 &&
                                                              itemGroups[index][
                                                                      'groupImage'] !=
                                                                  null))
                                                        Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                    top: 25,
                                                                    left: 5,
                                                                    right: 5,
                                                                    bottom: 5),
                                                            child: Image.memory(
                                                                itemViewType == 0
                                                                    ? getBytesOfCategoryImage(
                                                                        index)
                                                                    : getBytesOfGroupImage(index),
                                                                width: 100,
                                                                // cacheWidth: 100,
                                                                // cacheHeight: 100,
                                                                gaplessPlayback: true,
                                                                fit: BoxFit.fitWidth))
                                                    ],
                                                  ))),
                                        ),
                                      ),
                                    ))),
                          ),
                        )
                      else if (!isDataLoading)
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: MediaQuery.of(context).size.height - 275,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 5, left: 5),
                            child: Container(
                                alignment: Alignment.topLeft,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.deepOrangeAccent),
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(5)),
                                ),
                                child: Padding(
                                    padding: const EdgeInsets.all(5),
                                    child: /* ITEM VIEW */
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                right: 5, left: 5),
                                            child: SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.6,
                                              child: SingleChildScrollView(
                                                child: DataTable(
                                                  columns: const [
                                                    DataColumn(
                                                        label: Text('Resim')),
                                                    DataColumn(
                                                        label:
                                                            Text('Stok Adı')),
                                                    DataColumn(
                                                        label:
                                                            Text('Kategori')),
                                                    DataColumn(
                                                        label: Text('Grubu')),
                                                    DataColumn(
                                                        label: Text('#')),
                                                  ],
                                                  rows: List<DataRow>.generate(
                                                    filteredItems.length,
                                                    (int index) => DataRow(
                                                      color: MaterialStateProperty
                                                          .resolveWith<
                                                              Color?>((Set<
                                                                  MaterialState>
                                                              states) {
                                                        // All rows will have the same selected color.
                                                        if (states.contains(
                                                            MaterialState
                                                                .selected)) {
                                                          return Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .primary
                                                              .withOpacity(
                                                                  0.08);
                                                        }
                                                        // Even rows will have a grey color.
                                                        if (index.isEven) {
                                                          return Colors.grey
                                                              .withOpacity(0.3);
                                                        }
                                                        return null; // Use default value for other states and odd rows.
                                                      }),
                                                      cells: <DataCell>[
                                                        if (_getItemRowData(
                                                                    index,
                                                                    'itemImage') !=
                                                                null &&
                                                            _getItemRowData(
                                                                        index,
                                                                        'itemImage')
                                                                    .toString()
                                                                    .length >
                                                                0)
                                                          DataCell(Image.memory(
                                                              getBytesOfItemImage(
                                                                  index),
                                                              width: 100,
                                                              // cacheWidth: 100,
                                                              // cacheHeight: 100,
                                                              gaplessPlayback:
                                                                  true,
                                                              fit: BoxFit
                                                                  .fitWidth))
                                                        else
                                                          DataCell(Text('')),
                                                        DataCell(Text(
                                                            _getItemRowData(
                                                                index,
                                                                'itemName'),
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        14))),
                                                        DataCell(Text(
                                                            _getItemRowData(
                                                                index,
                                                                'itemCategoryName'),
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        14))),
                                                        DataCell(Text(
                                                            _getItemRowData(
                                                                index,
                                                                'itemGroupName'),
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        14))),
                                                        DataCell(Row(
                                                          children: [
                                                            OutlinedButton(
                                                              style: ButtonStyle(
                                                                  shape: MaterialStateProperty.all(RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              5.0))),
                                                                  side: MaterialStateProperty.all(const BorderSide(
                                                                      color: Colors
                                                                          .black87,
                                                                      width: 1,
                                                                      style: BorderStyle
                                                                          .solid))),
                                                              onPressed: () =>
                                                                  _appendItem(
                                                                      index),
                                                              child: const Icon(
                                                                Icons.add,
                                                                size: 26.0,
                                                              ),
                                                            ),
                                                            OutlinedButton(
                                                              style: ButtonStyle(
                                                                  shape: MaterialStateProperty.all(RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              5.0))),
                                                                  side: MaterialStateProperty.all(const BorderSide(
                                                                      color: Colors
                                                                          .black87,
                                                                      width: 1,
                                                                      style: BorderStyle
                                                                          .solid))),
                                                              onPressed: () =>
                                                                  _showQuantityDialog(
                                                                      index),
                                                              child: const Icon(
                                                                Icons.keyboard,
                                                                size: 26.0,
                                                              ),
                                                            )
                                                            // Padding(
                                                            //   padding:
                                                            //       const EdgeInsets
                                                            //               .only(
                                                            //           left: 5),
                                                            //   child:
                                                            //       OutlinedButton(
                                                            //     style: ButtonStyle(
                                                            //         shape: MaterialStateProperty.all(RoundedRectangleBorder(
                                                            //             borderRadius:
                                                            //                 BorderRadius.circular(
                                                            //                     5.0))),
                                                            //         side: MaterialStateProperty.all(const BorderSide(
                                                            //             color: Colors
                                                            //                 .black87,
                                                            //             width:
                                                            //                 1,
                                                            //             style: BorderStyle
                                                            //                 .solid))),
                                                            //     onPressed: () =>
                                                            //         _showItemImage(
                                                            //             index),
                                                            //     child:
                                                            //         const Icon(
                                                            //       Icons.image,
                                                            //       size: 26.0,
                                                            //     ),
                                                            //   ),
                                                            // )
                                                          ],
                                                        ))
                                                      ],
                                                    ),
                                                  ),
                                                  dividerThickness: 5,
                                                  dataRowHeight: 80,
                                                  showCheckboxColumn: false,
                                                  showBottomBorder: true,
                                                  headingTextStyle:
                                                      const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white),
                                                  headingRowColor:
                                                      MaterialStateProperty
                                                          .resolveWith(
                                                              (states) => Colors
                                                                  .deepOrangeAccent),
                                                ),
                                              ),
                                            )))),
                          ),
                        )
                      else
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: MediaQuery.of(context).size.height - 275,
                          child: Image.asset(
                            'image/asset/loading.gif',
                            height: 60,
                            fit: BoxFit.scaleDown,
                          ),
                        )
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
