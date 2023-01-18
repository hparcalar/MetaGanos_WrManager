import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

var _saleHistoryData = [];

String _getTableData(int index, String field) {
  return _saleHistoryData[index][field].toString();
}

String dbDateToHumanDate(String date) {
  var splittedData = date.split('-');
  return splittedData[2] + '.' + splittedData[1] + '.' + splittedData[0];
}

var txtStartDate = TextEditingController();
var txtEndDate = TextEditingController();

Future<void> showSaleHistory(BuildContext context, var rawData, String stDate,
    String enDate, Function callback) async {
  _saleHistoryData = rawData;
  txtStartDate.text = stDate;
  txtEndDate.text = enDate;

  return showDialog<void>(
    context: context,
    barrierDismissible: true, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Geçmiş Alımlar'),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                  // height: 100,
                  // color: Colors.blue,
                  child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 200,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: TextFormField(
                        controller: txtStartDate,
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(
                                  2000), //DateTime.now() - not to allow to choose before today.
                              lastDate: DateTime(2101));

                          if (pickedDate != null) {
                            String formattedDate =
                                DateFormat('yyyy-MM-dd').format(pickedDate);
                            txtStartDate.text = formattedDate;
                          } else {}
                        },
                        decoration: const InputDecoration(
                          border: UnderlineInputBorder(),
                          labelText: 'Baş. Tarih',
                        ),
                        enableSuggestions: false,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: TextFormField(
                        controller: txtEndDate,
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(
                                  2000), //DateTime.now() - not to allow to choose before today.
                              lastDate: DateTime(2101));

                          if (pickedDate != null) {
                            String formattedDate =
                                DateFormat('yyyy-MM-dd').format(pickedDate);
                            txtEndDate.text = formattedDate;
                          } else {}
                        },
                        decoration: const InputDecoration(
                          border: UnderlineInputBorder(),
                          labelText: 'Bit. Tarih',
                        ),
                        enableSuggestions: false,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: ElevatedButton(
                        onPressed: () => {
                          callback(txtStartDate.text, txtEndDate.text),
                          Navigator.of(context).pop(),
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(5),
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
              )),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6 - 100,
                child: SingleChildScrollView(
                  child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Tarih')),
                        DataColumn(label: Text('Saat')),
                        DataColumn(label: Text('Personel')),
                        DataColumn(label: Text('Kategori')),
                        DataColumn(label: Text('Stok')),
                        DataColumn(label: Text('Miktar')),
                      ],
                      rows: List<DataRow>.generate(
                        _saleHistoryData.length,
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
                              dbDateToHumanDate(
                                  _getTableData(index, 'consumedDate')
                                      .substring(0, 10)),
                            )),
                            DataCell(Text(
                              _getTableData(index, 'consumedDate')
                                  .substring(11, 16),
                            )),
                            DataCell(Text(
                              _getTableData(index, 'employeeName'),
                            )),
                            DataCell(Text(
                              _getTableData(index, 'itemCategoryName'),
                            )),
                            DataCell(Text(
                              _getTableData(index, 'itemName'),
                            )),
                            DataCell(Text(
                              _getTableData(index, 'totalConsumed'),
                            )),
                          ],
                        ),
                      ),
                      dividerThickness: 0,
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
