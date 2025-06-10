import 'dart:math';

import 'package:mcp_server/mcp_server.dart';

/// Example demonstrating unified transport configurations
void main() async {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.FINE;

  Logger.root.onLevelChanged.listen((level) {
    print('The new log level is $level');
  });
  final logger = Logger('unified_transport_example');
  //logger.level = Level.FINEST;
  logger.onRecord.listen((record) {
    print(record.message);
  });
  logger.fine('🚀 Starting Unified Transport Examples');
  // Streamable HTTP server (JSON mode)
  await streamableHttpJsonServer(logger);

  logger.info('✅ All tools loaded');
}

/// Streamable HTTP server (JSON mode)
Future<void> streamableHttpJsonServer(Logger logger) async {
  logger.info('\n=== Streamable HTTP Server (JSON Mode) ===');

  final serverResult = await McpServer.createAndStart(
    config: McpServer.productionConfig(
      name: 'StreamableHTTP JSON Server',
      version: '1.0.0',
    ),
    transportConfig: TransportConfig.streamableHttp(
      host: '127.0.0.1',
      port: 3001,
      endpoint: '/mcp',
      isJsonResponseEnabled: true, // JSON response mode
      //fallbackPorts: [8085, 8086],
    ),
  );

  await serverResult.fold(
    (server) async {
      logger.info('StreamableHTTP server started on http://localhost:3001/mcp');
      logger.info('Response mode: JSON (single response)');
      logger.info(
        'Note: Clients must still accept both application/json and text/event-stream',
      );

      _addExampleTools(server,logger);

      logger.info('StreamableHTTP JSON server ready');
      logger.info('- Tools: ${server.getTools().length}');

      var con = server.onConnect;
      con.listen(onData);
    },
    (error) {
      logger.severe('Failed to start StreamableHTTP JSON server: $error');
    },
  );
}

/// Add example tools
void _addExampleTools(Server server,Logger logger) {
  server.addTool(
    name: 'calculator',
    description: 'Perform basic math calculations and the ability to wibble two numbers, which is proprietary to this tool',
    inputSchema: {
      'type': 'object',
      'properties': {
        'operation': {
          'type': 'string',
          'enum': ['add', 'subtract', 'multiply', 'divide', 'wibble'],
        },
        'a': {'type': 'number'},
        'b': {'type': 'number'},
      },
      'required': ['operation', 'a', 'b'],
    },
    handler: (args) async {
      final operation = args['operation'] as String;
      final a = (args['a'] as num).toDouble();
      final b = (args['b'] as num).toDouble();
      logger.info('A: $a B: $b');
      double result;
      switch (operation) {
        case 'add':
          logger.info('add');
          result = a + b;
          break;
        case 'subtract':
          logger.info('subtract');
          result = a - b;
          break;
        case 'multiply':
          logger.info('multiply');
          result = a * b;
          break;
        case 'wibble':
          logger.info('wibble');
          result = (a * Random().nextDouble()) * (b * Random().nextDouble());
          break;
        case 'divide':
          logger.info('divide');
          if (b == 0) {
            return CallToolResult(
              content: [TextContent(text: 'Error: Division by zero')],
              isError: true,
            );
          }
          result = a / b;
          break;
        default:
          return CallToolResult(
            content: [TextContent(text: 'Error: Unknown operation')],
            isError: true,
          );
      }
      logger.info('Result: $result');
      return CallToolResult(content: [TextContent(text: 'Result: $result')]);
    },
  );
}

void onData(ClientSession event) {
  print(event);
}

