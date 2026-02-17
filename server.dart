import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Simple YAML server for vbet-partner-app
/// Serves YAML screens and router config for all regions
void main() async {
  const port = 8080;
  const host = '0.0.0.0';

  print('🚀 Starting YAML Server...');

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsHeaders())
      .addHandler(_handleRequest);

  final server = await shelf_io.serve(handler, host, port);

  print('🚀 YAML Server started on http://127.0.0.1:$port');
  print('📁 Serving files from: $_apiRoot');
  print('');
  print('Available endpoints:');
  print('  - GET /health');
  print('  - GET /api/config/router_{region}.yaml');
  print('  - GET /api/screens/{region}/{screen}.yaml');
  print('');
  print('Press Ctrl+C to stop');

  await ProcessSignal.sigint.watch().first;
  await server.close(force: true);
  exit(0);
}

/// CORS headers middleware
Middleware _corsHeaders() {
  return (Handler handler) {
    return (Request request) async {
      final response = await handler(request);
      return response.change(
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      );
    };
  };
}

// Resolve the api/ folder from the project root.
// When run with `dart run lib/yaml_ui_integration/yaml_server/server.dart`
// from the project root, Directory.current is the project root.
// Platform.script may point to a .dart_tool snapshot (not the source file),
// so we use Directory.current + the known relative path instead.
final _apiRoot = () {
  // Prefer explicit env var override (useful in CI or custom setups)
  final envOverride = Platform.environment['YAML_SERVER_ROOT'];
  if (envOverride != null && envOverride.isNotEmpty) return envOverride;

  // Walk up from the script file path: handles both `dart run` and direct execution
  // server.dart is at: lib/yaml_ui_integration/yaml_server/server.dart
  // so 3 levels up is the project root, and api/ is alongside server.dart
  final scriptFile = File(Platform.script.toFilePath());
  final scriptDir = scriptFile.parent;

  // If the script dir contains an 'api' subfolder we're at the right place
  if (Directory('${scriptDir.path}/api').existsSync()) {
    return scriptDir.path;
  }

  // Fallback: project root + known relative path
  final projectRoot = Directory.current.path;
  return '$projectRoot/lib/yaml_ui_integration/yaml_server';
}();

/// Handle all requests
Future<Response> _handleRequest(Request request) async {
  final path = request.url.path;

  // Health check
  if (path == 'health') {
    return Response.ok(
      '{"status":"ok","timestamp":"${DateTime.now().toIso8601String()}"}',
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Router config:  /api/config/router_{region}.yaml
  if (path.startsWith('api/config/router_') && path.endsWith('.yaml')) {
    return _serveYamlFile('$_apiRoot/$path');
  }

  // Screen requests: /api/screens/{region}/{screen}.yaml
  if (path.startsWith('api/screens/') && path.endsWith('.yaml')) {
    return _serveScreenYaml(path);
  }

  return Response.notFound('Not found: $path');
}

/// Serve any YAML file by absolute path
Future<Response> _serveYamlFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    print('  ❌ YAML not found: $filePath');
    return Response.notFound('YAML file not found: $filePath');
  }
  final content = await file.readAsString();
  print('[${DateTime.now()}] Served: $filePath');
  return Response.ok(
    content,
    headers: {
      'Content-Type': 'text/yaml',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    },
  );
}

/// Serve a screen YAML, falling back to vbet_ua if region-specific not found
Future<Response> _serveScreenYaml(String path) async {
  try {
    // path = api/screens/{region}/{screen}.yaml
    final parts = path.split('/'); // ['api','screens','{region}','{screen}.yaml']
    final region = parts[2];
    final screenFile = parts[3];

    // Try region-specific file first, fall back to vbet_ua
    var yamlPath = '$_apiRoot/api/screens/$region/$screenFile';
    var file = File(yamlPath);

    if (!await file.exists()) {
      yamlPath = '$_apiRoot/api/screens/vbet_ua/$screenFile';
      file = File(yamlPath);
    }

    if (!await file.exists()) {
      print('  ❌ YAML not found for region: $region, screen: $screenFile');
      return Response.notFound('YAML file not found: $region/$screenFile');
    }

    final content = await file.readAsString();
    print('[${DateTime.now()}] GET /api/screens/$region/$screenFile');
    print('  ✅ Served: $yamlPath');

    return Response.ok(
      content,
      headers: {
        'Content-Type': 'text/yaml',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
      },
    );
  } catch (e) {
    print('  ❌ Error serving YAML: $e');
    return Response.internalServerError(body: 'Error serving YAML: $e');
  }
}
