import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

part 'supabase_client_provider.g.dart';

/// DI seam exposing the bootstrapped Supabase client to the provider graph.
///
/// Lives in core/network — the layer that owns Supabase — so feature
/// application/providers no longer need to import supabase_flutter or
/// touch `SupabaseService.client` outside their data/datasources layer.
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) => SupabaseService.client;
