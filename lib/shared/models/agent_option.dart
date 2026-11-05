import '../../core/constants/backend_config.dart';

/// Un agent proposé à l'utilisateur, tel que déclaré dans les `modelSpecs`
/// de LibreChat (`GET /api/config`, session authentifiée).
///
/// Le couple [specName] / [agentId] doit être envoyé ensemble : avec
/// `modelSpecs.enforce`, LibreChat refuse un agent envoyé sous une autre spec.
class AgentOption {
  const AgentOption({
    required this.specName,
    required this.label,
    required this.agentId,
    this.description = '',
    this.isDefault = false,
  });

  final String specName;
  final String label;
  final String agentId;
  final String description;
  final bool isDefault;

  /// Agent historique de l'application, utilisé si la configuration serveur
  /// ne peut pas être lue.
  static const fallback = AgentOption(
    specName: BackendConfig.chatSpec,
    label: 'Assistant',
    agentId: BackendConfig.chatAgentId,
    isDefault: true,
  );

  /// Extrait les agents des `modelSpecs` de `/api/config`. Les entrées qui ne
  /// pointent pas vers un agent sont ignorées. Renvoie [fallback] seul si rien
  /// d'exploitable n'est trouvé.
  static List<AgentOption> fromConfig(Map<String, dynamic>? config) {
    final specs = config?['modelSpecs'];
    final list = specs is Map ? specs['list'] : null;
    if (list is! List) {
      return const [fallback];
    }

    final options = <AgentOption>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final preset = raw['preset'];
      if (preset is! Map) continue;
      final agentId = preset['agent_id']?.toString().trim() ?? '';
      final specName = raw['name']?.toString().trim() ?? '';
      if (agentId.isEmpty || specName.isEmpty) continue;
      final label = raw['label']?.toString().trim() ?? '';
      options.add(
        AgentOption(
          specName: specName,
          label: label.isEmpty ? specName : label,
          agentId: agentId,
          description: raw['description']?.toString().trim() ?? '',
          isDefault: raw['default'] == true,
        ),
      );
    }
    return options.isEmpty ? const [fallback] : options;
  }
}
