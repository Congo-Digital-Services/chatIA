import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsControllerProvider = ChangeNotifierProvider<SettingsController>((
  ref,
) {
  return SettingsController()..loadFromPrefs();
});

class SettingsController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Color _accentColor = const Color(0xFF18B489);
  String _language = 'fr';
  String _shortcutAction =
      'none'; // 'none', 'voice_call', 'file_picker', 'create_note', 'new_chat'
  String _voiceEngine = 'local'; // 'local', 'server'

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  String get language => _language;
  String get shortcutAction => _shortcutAction;
  String get voiceEngine => _voiceEngine;

  // ── Persistence ──────────────────────────────────────────────────────────────
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString('themeMode') ?? 'light';
      _themeMode = themeStr == 'dark'
          ? ThemeMode.dark
          : themeStr == 'system'
          ? ThemeMode.system
          : ThemeMode.light;
      final accentVal = prefs.getInt('accentColor');
      if (accentVal != null) {
        _accentColor = Color(accentVal);
      }
      _language = prefs.getString('language') ?? 'fr';
      _shortcutAction = prefs.getString('shortcutAction') ?? 'none';
      _voiceEngine = prefs.getString('voiceEngine') ?? 'local';
      notifyListeners();
    } catch (_) {
      // SharedPreferences not available (e.g. web without storage) — ignore
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = _themeMode == ThemeMode.dark
          ? 'dark'
          : _themeMode == ThemeMode.system
          ? 'system'
          : 'light';
      await prefs.setString('themeMode', themeStr);
      await prefs.setInt('accentColor', _accentColor.toARGB32());
      await prefs.setString('language', _language);
      await prefs.setString('shortcutAction', _shortcutAction);
      await prefs.setString('voiceEngine', _voiceEngine);
    } catch (_) {}
  }

  // ── Setters ──────────────────────────────────────────────────────────────────
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    _save();
  }

  void setAccentColor(Color color) {
    _accentColor = color;
    notifyListeners();
    _save();
  }

  void setLanguage(String lang) {
    if (supportedLanguages.containsKey(lang)) {
      _language = lang;
      notifyListeners();
      _save();
    }
  }

  void setShortcutAction(String action) {
    _shortcutAction = action;
    notifyListeners();
    _save();
  }

  void setVoiceEngine(String engine) {
    _voiceEngine = engine;
    notifyListeners();
    _save();
  }

  String translate(String key) {
    // Fallback order: requested lang → fr → en → key itself
    final lang = localizations.containsKey(_language) ? _language : 'fr';
    return localizations[lang]?[key] ?? localizations['fr']?[key] ?? key;
  }

  /// Native display name for the given language code.
  static String languageName(String code) => supportedLanguages[code] ?? code;
}

// ─── Langues supportées (5 sélectionnées) ────────────────────────────────────
const Map<String, String> supportedLanguages = {
  'en': 'English',
  'fr': 'Français',
  'pt': 'Português',
  'es': 'Español',
  'sw': 'Swahili',
};

// ─── Localizations ───────────────────────────────────────────────────────────
const Map<String, Map<String, String>> localizations = {
  'fr': {
    'settings_title': 'Personnalisation',
    'display': 'Affichage',
    'dark_mode': 'Mode sombre',
    'theme_light': 'Thème clair actif',
    'theme_dark': 'Thème sombre actif',
    'theme_system': 'Thème système actif',
    'accent_palette': 'Palette d\'accent',
    'shortcuts': 'Raccourcis rapides',
    'shortcut_none': 'Aucune action sélectionnée',
    'shortcut_voice_call': 'Lancer un appel vocal IA',
    'shortcut_file_picker': 'Ouvrir l\'explorateur de fichiers',
    'shortcut_create_note': 'Créer une note rapide',
    'shortcut_new_chat': 'Nouvelle conversation',
    'language': 'Langue',
    'app_language': 'Langue de l\'application',
    'lang_system': 'Système',
    'lang_fr': 'Français',
    'lang_en': 'English',
    'lang_pt': 'Português',
    'lang_es': 'Español',
    'lang_sw': 'Swahili',
    'voice_dictation': 'Voix & Dictée',
    'recognition_engine': 'Moteur de reconnaissance',
    'local_device': 'Sur l\'appareil',
    'server': 'Serveur',
    'voice_note':
        'Audio traité localement sur l\'appareil. La dictée nécessite que la reconnaissance vocale sur appareil soit disponible.',
    'profile': 'Profil',
    'session': 'Session',
    'sign_out': 'Se déconnecter',
    'session_mock':
        'Connexion simulée active. Renseignez les constantes Keycloak pour activer le vrai flux SSO.',
    'session_keycloak': 'Connecté via Keycloak.',
    'menu': 'Menu',
    'voice_call_ai': 'Appel vocal IA',
    'new_note': 'Nouvelle note',
    'new_conversation': 'Nouvelle conversation',
    'message_hint': 'Message…',
    'dictate': 'Dicter',
    'attach_file': 'Joindre un fichier',
    'cancel': 'Annuler',
    'recent': 'Récentes',
    'pinned': 'Épinglées',
    'notes_tab': 'Notes',
    'channels_tab': 'Canaux',
    'folders_tab': 'Dossiers',
    'create_channel': 'Créer un canal',
    'channel_name': 'Nom du canal',
    'enter_channel_name': 'Entrez le nom du canal',
    'back': 'Retour',
    'search_hint': 'Rechercher...',
    'no_conversations': 'Aucune conversation',
    'loading': 'Chargement...',
    'kimi_k2': 'Kimi K2',
    'bloc_notes': 'Bloc-notes',
    'select_theme': 'Sélectionner le mode sombre',
    'select_shortcut': 'Sélectionner l\'action rapide',
    'select_language': 'Sélectionner la langue',
    'light': 'Clair',
    'dark': 'Sombre',
    'system': 'Système',
  },
  'en': {
    'settings_title': 'Personalization',
    'display': 'Display',
    'dark_mode': 'Dark mode',
    'theme_light': 'Light theme active',
    'theme_dark': 'Dark theme active',
    'theme_system': 'System theme active',
    'accent_palette': 'Accent palette',
    'shortcuts': 'Quick shortcuts',
    'shortcut_none': 'No action selected',
    'shortcut_voice_call': 'Start an AI voice call',
    'shortcut_file_picker': 'Open file explorer',
    'shortcut_create_note': 'Create a quick note',
    'shortcut_new_chat': 'New conversation',
    'language': 'Language',
    'app_language': 'App language',
    'lang_system': 'System',
    'lang_fr': 'Français',
    'lang_en': 'English',
    'lang_pt': 'Português',
    'lang_es': 'Español',
    'lang_sw': 'Swahili',
    'voice_dictation': 'Voice & Dictation',
    'recognition_engine': 'Recognition engine',
    'local_device': 'On device',
    'server': 'Server',
    'voice_note':
        'Audio processed locally on device. Dictation requires on-device voice recognition to be available.',
    'profile': 'Profile',
    'session': 'Session',
    'sign_out': 'Log out',
    'session_mock':
        'Mock connection active. Fill Keycloak constants to enable real SSO flow.',
    'session_keycloak': 'Connected via Keycloak.',
    'menu': 'Menu',
    'voice_call_ai': 'AI Voice Call',
    'new_note': 'New note',
    'new_conversation': 'New conversation',
    'message_hint': 'Message…',
    'dictate': 'Dictate',
    'attach_file': 'Attach a file',
    'cancel': 'Cancel',
    'recent': 'Recent',
    'pinned': 'Pinned',
    'notes_tab': 'Notes',
    'channels_tab': 'Channels',
    'folders_tab': 'Folders',
    'create_channel': 'Create channel',
    'channel_name': 'Channel name',
    'enter_channel_name': 'Enter channel name',
    'back': 'Back',
    'search_hint': 'Search...',
    'no_conversations': 'No conversations',
    'loading': 'Loading...',
    'kimi_k2': 'Kimi K2',
    'bloc_notes': 'Notepad',
    'select_theme': 'Select dark mode',
    'select_shortcut': 'Select quick shortcut',
    'select_language': 'Select language',
    'light': 'Light',
    'dark': 'Dark',
    'system': 'System',
  },
  'es': {
    'settings_title': 'Personalización',
    'display': 'Pantalla',
    'dark_mode': 'Modo oscuro',
    'theme_light': 'Tema claro activo',
    'theme_dark': 'Tema oscuro activo',
    'theme_system': 'Tema del sistema activo',
    'accent_palette': 'Paleta de acento',
    'shortcuts': 'Atajos rápidos',
    'shortcut_none': 'Ninguna acción seleccionada',
    'shortcut_voice_call': 'Iniciar llamada de voz IA',
    'shortcut_file_picker': 'Abrir explorador de archivos',
    'shortcut_create_note': 'Crear nota rápida',
    'shortcut_new_chat': 'Nueva conversación',
    'language': 'Idioma',
    'app_language': 'Idioma de la aplicação',
    'lang_system': 'Sistema',
    'lang_fr': 'Français',
    'lang_en': 'English',
    'lang_pt': 'Português',
    'lang_es': 'Español',
    'lang_sw': 'Swahili',
    'voice_dictation': 'Voz y dictado',
    'recognition_engine': 'Motor de reconocimiento',
    'local_device': 'En el dispositivo',
    'server': 'Servidor',
    'voice_note':
        'Audio procesado localmente en el dispositivo. El dictado requiere que la reconocimiento de voz esté disponible.',
    'profile': 'Perfil',
    'session': 'Sesión',
    'sign_out': 'Cerrar sesión',
    'session_mock':
        'Conexión simulada activa. Rellene las constantes de Keycloak para activar el flujo SSO real.',
    'session_keycloak': 'Conectado a través de Keycloak.',
    'menu': 'Menú',
    'voice_call_ai': 'Llamada de voz IA',
    'new_note': 'Nueva nota',
    'new_conversation': 'Nueva conversación',
    'message_hint': 'Mensaje…',
    'dictate': 'Dictar',
    'attach_file': 'Adjuntar archivo',
    'cancel': 'Cancelar',
    'recent': 'Recientes',
    'pinned': 'Fijados',
    'notes_tab': 'Notas',
    'channels_tab': 'Canales',
    'folders_tab': 'Carpetas',
    'create_channel': 'Crear canal',
    'channel_name': 'Nombre del canal',
    'enter_channel_name': 'Ingrese el nombre del canal',
    'back': 'Atrás',
    'search_hint': 'Buscar...',
    'no_conversations': 'Sin conversaciones',
    'loading': 'Cargando...',
    'kimi_k2': 'Kimi K2',
    'bloc_notes': 'Bloc de notas',
    'select_theme': 'Seleccionar modo oscuro',
    'select_shortcut': 'Seleccionar atajo rápido',
    'select_language': 'Seleccionar idioma',
    'light': 'Claro',
    'dark': 'Oscuro',
    'system': 'Sistema',
  },
  'pt': {
    'settings_title': 'Personalização',
    'display': 'Exibição',
    'dark_mode': 'Modo escuro',
    'theme_light': 'Tema claro activo',
    'theme_dark': 'Tema escuro activo',
    'theme_system': 'Tema do sistema activo',
    'accent_palette': 'Paleta de cores',
    'shortcuts': 'Atalhos rápidos',
    'shortcut_none': 'Nenhuma ação selecionada',
    'shortcut_voice_call': 'Iniciar chamada de voz por IA',
    'shortcut_file_picker': 'Abrir gerenciador de arquivos',
    'shortcut_create_note': 'Criar nota rápida',
    'shortcut_new_chat': 'Nova conversa',
    'language': 'Idioma',
    'app_language': 'Idioma do aplicativo',
    'lang_system': 'Sistema',
    'lang_fr': 'Français',
    'lang_en': 'English',
    'lang_pt': 'Português',
    'lang_es': 'Espanhol',
    'lang_sw': 'Swahili',
    'voice_dictation': 'Voz e Ditado',
    'recognition_engine': 'Mecanismo de reconhecimento',
    'local_device': 'No dispositivo',
    'server': 'Servidor',
    'voice_note':
        'Áudio processado localmente no dispositivo. O ditado requer reconhecimento de voz no dispositivo disponível.',
    'profile': 'Perfil',
    'session': 'Sessão',
    'sign_out': 'Sair',
    'session_mock':
        'Conexão simulada ativa. Preencha as constantes do Keycloak para ativar o fluxo SSO real.',
    'session_keycloak': 'Conectado via Keycloak.',
    'menu': 'Menu',
    'voice_call_ai': 'Chamada de voz por IA',
    'new_note': 'Nova nota',
    'new_conversation': 'Nova conversa',
    'message_hint': 'Mensagem…',
    'dictate': 'Ditar',
    'attach_file': 'Anexar arquivo',
    'cancel': 'Cancelar',
    'recent': 'Recientes',
    'pinned': 'Fixados',
    'notes_tab': 'Notas',
    'channels_tab': 'Canais',
    'folders_tab': 'Pastas',
    'create_channel': 'Criar canal',
    'channel_name': 'Nome do canal',
    'enter_channel_name': 'Digite o nome do canal',
    'back': 'Voltar',
    'search_hint': 'Pesquisar...',
    'no_conversations': 'Nenhuma conversa',
    'loading': 'Carregando...',
    'kimi_k2': 'Kimi K2',
    'bloc_notes': 'Bloco de notas',
    'select_theme': 'Selecionar modo escuro',
    'select_shortcut': 'Selecionar atalhos rápidos',
    'select_language': 'Selecionar idioma',
    'light': 'Claro',
    'dark': 'Escuro',
    'system': 'Sistema',
  },
  'sw': {
    'settings_title': 'Kubinafsisha',
    'display': 'Onyesho',
    'dark_mode': 'Hali ya giza',
    'theme_light': 'Mandhari mepesi yameamilishwa',
    'theme_dark': 'Mandhari ya giza yameamilishwa',
    'theme_system': 'Mandhari ya mfumo yameamilishwa',
    'accent_palette': 'Ubao wa rangi ya lafudhi',
    'shortcuts': 'Njia za mkato za haraka',
    'shortcut_none': 'Hakuna hatua iliyochaguliwa',
    'shortcut_voice_call': 'Anzisha simu ya sauti ya AI',
    'shortcut_file_picker': 'Fungua kivinjari cha faili',
    'shortcut_create_note': 'Unda kumbukumbu ya haraka',
    'shortcut_new_chat': 'Mazungumzo mapya',
    'language': 'Lugha',
    'app_language': 'Lugha ya programu',
    'lang_system': 'Mfumo',
    'lang_fr': 'Français',
    'lang_en': 'English',
    'lang_pt': 'Português',
    'lang_es': 'Español',
    'lang_sw': 'Swahili',
    'voice_dictation': 'Sauti na Imla',
    'recognition_engine': 'Injini ya utambuzi',
    'local_device': 'Kwenye kifaa',
    'server': 'Seva',
    'voice_note':
        'Sauti inachakatwa kwenye kifaa. Imla inahitaji utambuzi wa sauti kwenye kifaa kupatikana.',
    'profile': 'Wasifu',
    'session': 'Kipindi',
    'sign_out': 'Ondoka',
    'session_mock':
        'Muunganisho wa mfano unafanya kazi. Jaza vigezo vya Keycloak ili kuwezesha mtiririko halisi wa SSO.',
    'session_keycloak': 'Imeunganishwa kupitia Keycloak.',
    'menu': 'Menyu',
    'voice_call_ai': 'Simu ya Sauti ya AI',
    'new_note': 'Kumbukumbu mpya',
    'new_conversation': 'Mazungumzo mapya',
    'message_hint': 'Ujumbe…',
    'dictate': 'Imla',
    'attach_file': 'Ambatisha faili',
    'cancel': 'Ghairi',
    'recent': 'Hivi karibuni',
    'pinned': 'Zilizobandikwa',
    'notes_tab': 'Kumbukumbu',
    'channels_tab': 'Vituo',
    'folders_tab': 'Folda',
    'create_channel': 'Unda kituo',
    'channel_name': 'Jina la kituo',
    'enter_channel_name': 'Ingiza jina la kituo',
    'back': 'Nyuma',
    'search_hint': 'Tafuta...',
    'no_conversations': 'Hakuna mazungumzo',
    'loading': 'Inapakia...',
    'kimi_k2': 'Kimi K2',
    'bloc_notes': 'Kikumbusho',
    'select_theme': 'Chagua hali ya giza',
    'select_shortcut': 'Chagua njia ya mkato ya haraka',
    'select_language': 'Chagua lugha',
    'light': 'Nuru',
    'dark': 'Giza',
    'system': 'Mfumo',
  },
};
