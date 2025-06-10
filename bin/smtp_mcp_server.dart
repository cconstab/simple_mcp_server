import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:mcp_server/mcp_server.dart' hide Message;

import 'package:simple_mcp_server/smtp_vars.dart';

void main() async {
  // Get Variables via Environment rather than hard code/config files.
  Map<String, String> envVars = Platform.environment;
  String? username = envVars['SMTP_USERNAME'];
  String? password = envVars['SMTP_PASSWORD'];
  String? relay = envVars['SMTP_SERVER'];
  String? fullname = envVars['SMTP_FULLNAME'];

  if (username == null ||
      password == null ||
      relay == null ||
      fullname == null) {
    print(
      " Set up these Envirment varibles SMTP_USERNAME, SMTP_PASSWORD, SMTP_SERVER, SMTP_FULLNAME",
    );
    exit(1);
  }

  Smtp smtp = Smtp();

  smtp.fullName = fullname;
  smtp.relay = relay;
  smtp.password = password;
  smtp.username = username;

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
  await streamableHttpJsonServer(smtp: smtp, logger: logger);

  logger.info('✅ All tools loaded');
}

/// Streamable HTTP server (JSON mode)
Future<void> streamableHttpJsonServer({
  required Smtp smtp,
  required Logger logger,
}) async {
  logger.info('\n=== Example 4: Streamable HTTP Server (JSON Mode) ===');

  final serverResult = await McpServer.createAndStart(
    config: McpServer.productionConfig(
      name: 'StreamableHTTP JSON Server',
      version: '1.0.0',
    ),
    transportConfig: TransportConfig.streamableHttp(
      host: '127.0.0.1',
      port: 3002,
      endpoint: '/mcp',
      isJsonResponseEnabled: true, // JSON response mode
      //fallbackPorts: [8085, 8086],
    ),
  );

  await serverResult.fold(
    (server) async {
      logger.info('StreamableHTTP server started on http://localhost:3002/mcp');
      logger.info('Response mode: JSON (single response)');
      logger.info(
        'Note: Clients must still accept both application/json and text/event-stream',
      );

      _addEmailTool(server: server, logger: logger, smtp: smtp);

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
void _addEmailTool({
  required Server server,
  required Logger logger,
  required Smtp smtp,
}) {
  server.addTool(
    name: 'EmailSender',
    description: 'Send email to email addreses with subject and main text',
    inputSchema: {
      'type': 'object',
      'properties': {
        'operation': {
          'type': 'string',
          'enum': ['send'],
        },
        'address': {'type': 'string'},
        'subject': {'type': 'string'},
        'body': {'type': 'string'},
      },
      'required': ['address', 'subject', 'body'],
    },
    handler: (args) async {
      final address = args['address'] as String;
      final subject = args['subject'] as String;
      final body = args['body'] as String;
      String sent = await sendmail(
        address: address,
        subject: subject,
        body: body,
        smtp: smtp,
      );

      return CallToolResult(content: [TextContent(text: 'status: $sent')]);
    },
  );
}

void onData(ClientSession event) {
  print(event);
}

Future<String> sendmail({
  required String address,
  required String subject,
  required String body,
  required Smtp smtp,
}) async {
  // Note that using a username and password for gmail only works if
  // you have two-factor authentication enabled and created an App password.
  // Search for "gmail app password 2fa"
  // The alternative is to use oauth.
  print("""Address: $address
Subject: $subject  
Body: $body""");

  final smtpRelay = SmtpServer(
    smtp.relay!,
    username: smtp.username,
    password: smtp.password,
    allowInsecure: false,
  );
  // Use the SmtpServer class to configure an SMTP server:
  // final smtpServer = SmtpServer('smtp.domain.com');
  // See the named arguments of SmtpServer for further configuration
  // options.

  // Create our message.
  final message = Message()
    ..from = Address(smtp.username!, smtp.fullName)
    ..recipients.add(address)
    //..ccRecipients.addAll(['destCc1@example.com', 'destCc2@example.com'])
    //..bccRecipients.add(Address('bccAddress@example.com'))
    ..subject = '$subject :: Sent By Ai/MCP :: ${DateTime.now()}'
    ..text = body;

  try {
    final sendReport = await send(message, smtpRelay);
    print('Message sent: $sendReport');
    return ('sent');
  } on MailerException catch (e) {
    print('Message not sent.');
    for (var p in e.problems) {
      print('Problem: ${p.code}: ${p.msg}');
    }
    return ('not sent');
  }
  // DONE
}
