import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

var _empList = [];
var _filteredEmpList = [];
var _selectionCallback = null;
var _dialogContext = null;
var _stateFunc = null;

String _getTableData(int index, String field) {
  return _filteredEmpList[index][field].toString();
}

void selectEmployee(int index) {
  _selectionCallback(_filteredEmpList[index]);
  Navigator.of(_dialogContext).pop();
}

Future<void> showEmployeeList(
    BuildContext context, var rawData, Function callback) async {
  final txtSearchForEmployee = TextEditingController();
  final txtSearchForName = TextEditingController();
  final txtSearchForCard = TextEditingController();
  final txtSearchForDepartment = TextEditingController();
  var lastFilterReadDate = DateTime.now();
  var filterTimeOutIsRunning = false;

  void _runFilter() async {
    try {
      var search = RegExp(txtSearchForEmployee.text, caseSensitive: false);
      var searchName = RegExp(txtSearchForName.text, caseSensitive: false);
      var searchCard = RegExp(txtSearchForCard.text, caseSensitive: false);
      var searchDep = RegExp(txtSearchForDepartment.text, caseSensitive: false);

      _stateFunc(() {
        _filteredEmpList = _empList
            .where((d) =>
                search.hasMatch(d['employeeCode'].toString()) &&
                searchName.hasMatch(d['employeeName'].toString()) &&
                searchCard.hasMatch(d['employeeCardCode'].toString()) &&
                searchDep.hasMatch(d['departmentName'].toString()))
            .toList();
      });
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

  _dialogContext = context;
  _empList = rawData;
  _filteredEmpList = _empList;
  _selectionCallback = callback;

  return showDialog<void>(
    context: context,
    barrierDismissible: true, // user must tap button!
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          _stateFunc = setState;
          return AlertDialog(
            title: const Text('Personel Listesi'),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.height * 0.6 - 10,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  MediaQuery.of(context).size.width * 0.13 - 10,
                              child: RawKeyboardListener(
                                focusNode: FocusNode(),
                                child: TextFormField(
                                  autofocus: true,
                                  controller: txtSearchForEmployee,
                                  decoration: const InputDecoration(
                                    border: UnderlineInputBorder(),
                                    labelText: 'SICIL ARAMA',
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
                              width:
                                  MediaQuery.of(context).size.width * 0.13 - 10,
                              child: RawKeyboardListener(
                                focusNode: FocusNode(),
                                child: TextFormField(
                                  autofocus: true,
                                  controller: txtSearchForName,
                                  decoration: const InputDecoration(
                                    border: UnderlineInputBorder(),
                                    labelText: 'ISIM ARAMA',
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
                              width:
                                  MediaQuery.of(context).size.width * 0.13 - 10,
                              child: RawKeyboardListener(
                                focusNode: FocusNode(),
                                child: TextFormField(
                                  autofocus: true,
                                  controller: txtSearchForCard,
                                  decoration: const InputDecoration(
                                    border: UnderlineInputBorder(),
                                    labelText: 'KART ARAMA',
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
                              width:
                                  MediaQuery.of(context).size.width * 0.13 - 10,
                              child: RawKeyboardListener(
                                focusNode: FocusNode(),
                                child: TextFormField(
                                  autofocus: true,
                                  controller: txtSearchForDepartment,
                                  decoration: const InputDecoration(
                                    border: UnderlineInputBorder(),
                                    labelText: 'DEPARTMAN ARAMA',
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
                            width:
                                MediaQuery.of(context).size.width * 0.11 - 10,
                            height: 45,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: ElevatedButton(
                                onPressed: () => {
                                  txtSearchForEmployee.text = '',
                                  txtSearchForCard.text = '',
                                  txtSearchForName.text = '',
                                  txtSearchForDepartment.text = '',
                                  _runFilter(),
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                      ],
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6 - 90,
                    child: SingleChildScrollView(
                      child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Sicil')),
                            DataColumn(label: Text('Adı Soyadı')),
                            DataColumn(label: Text('Kart No')),
                            DataColumn(label: Text('Departman')),
                            DataColumn(label: Text('#'))
                          ],
                          rows: List<DataRow>.generate(
                            _filteredEmpList.length,
                            (int index) => DataRow(
                              color: MaterialStateProperty.resolveWith<Color?>(
                                  (Set<MaterialState> states) {
                                // All rows will have the same selected color.
                                if (states.contains(MaterialState.selected)) {
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
                                    _getTableData(index, 'employeeCode'),
                                    style: const TextStyle(fontSize: 20))),
                                DataCell(Text(
                                    _getTableData(index, 'employeeName'),
                                    style: const TextStyle(fontSize: 20))),
                                DataCell(Text(
                                    _getTableData(index, 'employeeCardCode'),
                                    style: const TextStyle(fontSize: 20))),
                                DataCell(Text(
                                    _getTableData(index, 'departmentName'),
                                    style: const TextStyle(fontSize: 20))),
                                DataCell(
                                  OutlinedButton(
                                    style: ButtonStyle(
                                        shape: MaterialStateProperty.all(
                                            RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        5.0))),
                                        side: MaterialStateProperty.all(
                                            const BorderSide(
                                                color: Colors.black,
                                                width: 1,
                                                style: BorderStyle.solid))),
                                    onPressed: () => selectEmployee(index),
                                    child: const Icon(
                                      Icons.play_circle,
                                      size: 26.0,
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                          dividerThickness: 5,
                          dataRowHeight: 80,
                          showCheckboxColumn: false,
                          showBottomBorder: true,
                          headingTextStyle: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white),
                          headingRowColor: MaterialStateProperty.resolveWith(
                              (states) => Colors.deepOrangeAccent)),
                    ),
                  )
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('KAPAT'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    },
  );
}
