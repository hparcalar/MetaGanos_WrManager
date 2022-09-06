import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

var _creditsData = [];

String _getTableData(int index, String field) {
  return _creditsData[index][field].toString();
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
                        DataColumn(label: Text('Kredi')),
                        DataColumn(label: Text('Kalan')),
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
                                style: const TextStyle(fontSize: 20))),
                            DataCell(Text(_getTableData(index, 'creditByRange'),
                                style: const TextStyle(fontSize: 20))),
                            DataCell(Text(_getTableData(index, 'rangeCredit'),
                                style: const TextStyle(fontSize: 20))),
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
}
