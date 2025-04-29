import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final helpTopics = [
      {'title': 'Agregar Productos', 'content': 'Para agregar un producto nuevo, ingresa a la sección "Productos" y toca el botón "+". Llena los campos como nombre, código de barra, precio y guarda.'},
      {'title': 'Vender Productos', 'content': 'En "Facturación", busca el producto por código de barra o nombre, agrega la cantidad, selecciona si es contado o crédito y confirma la venta.'},
      {'title': 'Ingreso a Inventario', 'content': 'Escanea o ingresa el código de barra del producto. Ajusta cantidad, costo y precio si es necesario y confirma el ingreso.'},
      {'title': 'Buscar Clientes', 'content': 'En "Clientes", puedes buscar por nombre o número de teléfono. También puedes crear un cliente nuevo desde esta sección.'},
      {'title': 'Registrar Pagos a Crédito', 'content': 'En el perfil del cliente, selecciona la factura pendiente y registra el pago. Puedes registrar un pago total o parcial.'},
      {'title': 'Imprimir Stickers', 'content': 'Al ingresar inventario de un producto, puedes imprimir stickers con el nombre, precio y código de barra del producto.'},
      {'title': 'Ver Reportes', 'content': 'En "Reportes", puedes generar reportes de facturación, inventario, productos vendidos, pagos a crédito y más, filtrando por fechas.'},
      {'title': 'Errores Comunes', 'content': 'Si no encuentras un producto, verifica que el código de barra esté registrado correctamente. Si una venta no se registra, revisa la conexión de la impresora.'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: helpTopics.length,
        itemBuilder: (context, index) {
          final topic = helpTopics[index];
          return Card(
            child: ListTile(
              title: Text(topic['title']!),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(topic['title']!),
                  content: Text(topic['content']!),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
