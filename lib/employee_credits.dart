import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

var _creditsData = [];

String _getTableData(int index, String field) {
  return _creditsData[index][field].toString();
}

String _trsRangeType(String rType, String rLength) {
  String _result = "";

  int rangeType = int.parse(rType);
  int rangeLength = int.parse(rLength);
  String rStr = "";

  if (rangeLength > 1) rStr = rangeLength.toString() + " ";

  switch (rangeType) {
    case 1:
      _result = rStr + "GÜNLÜK";
      break;
    case 2:
      _result = rStr + "HAFTALIK";
      break;
    case 3:
      _result = rStr + "AYLIK";
      break;
    case 4:
      _result = rStr + "SINIRSIZ";
      break;
    default:
  }

  return _result;
}

Future<void> showEmployeeCredits(BuildContext context, var rawData) async {
  _creditsData = rawData;

  return showDialog<void>(
    context: context,
    barrierDismissible: true, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Personel Bakiyesi'),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6 - 50,
                child: SingleChildScrollView(
                  child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Stok')),
                        DataColumn(label: Text('Periyot')),
                        DataColumn(label: Text('Kredi')),
                        DataColumn(label: Text('Kalan Bakiye')),
                      ],
                      rows: List<DataRow>.generate(
                        _creditsData.length,
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
                              _getTableData(index, 'itemName').length > 0
                                  ? _getTableData(index, 'itemName')
                                  : _getTableData(index, 'itemGroupName')
                                              .length >
                                          0
                                      ? _getTableData(index, 'itemGroupName')
                                      : _getTableData(
                                          index, 'itemCategoryName'),
                            )),
                            // DataCell(Text(_getTableData(index, 'creditByRange'),
                            //     style: const TextStyle(fontSize: 20))),
                            DataCell(Text(_trsRangeType(
                                _getTableData(index, 'rangeType'),
                                _getTableData(index, 'rangeLength')))),
                            DataCell(
                                Text(_getTableData(index, 'activeCredit'))),
                            DataCell(Text(_getTableData(index, 'rangeCredit'))),
                          ],
                        ),
                      ),
                      dividerThickness: 0,
                      columnSpacing: 2,
                      dataRowHeight: 25,
                      showCheckboxColumn: false,
                      showBottomBorder: true,
                      dataTextStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                      ),
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
}
