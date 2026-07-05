# Motor Conversacional Universal - checkpoint 901-1400

Data: 2026-07-05

Escopo: quarta fatia da meta de exaustao estrutural do Motor Conversacional Universal. Este relatorio adiciona 500 unidades funcionais auditaveis, numeradas de 901 a 1400.

Total acumulado formal: 1400 itens classificados. Em uma meta nominal de 4.000 unidades, isso representa 35%.

## Referencias comprovadas

- REF-WCAG-STATUS: W3C WCAG 2.2, Success Criterion 4.1.3 Status Messages.
- REF-SLACK-HISTORY: Slack `conversations.history`, historico, limites, erro e continuidade.
- REF-SLACK-PAGINATION: Slack Web API Pagination.
- REF-WHATSAPP-TYPING: Meta WhatsApp typing/read indicators.
- REF-TELEGRAM-ACTION: Telegram Bot API `sendChatAction`.
- REF-FLUTTER-SEMANTICS: Flutter `Semantics`, `MediaQuery`, `TextScaler`, widgets, rotas e lifecycle.
- REF-SCROLL-FINISH: `test/finish_phase_test.dart`, `sim/support/sim_finish_contract.dart`, `sim/ui/widgets/sim_typewriter.dart`.
- REF-SCROLL-SCHOOL: `test/school_completeness_test.dart`, `sim/school/*`, `aula_drawer_contract.dart`.
- REF-SCROLL-MEDIA: `test/media_phase_test.dart`, `sim/media/*`, `lesson_visual_pipeline.dart`, `software_render_catalog.dart`.
- REF-SCROLL-READY: `test/first_lesson_ready_window_test.dart`, `sim/lesson/*`.
- REF-SCROLL-CLOUD: `test/cloud_phase_test.dart`, `test/student_state_backup_sync_b_test.dart`, `sim/cloud/*`.
- REF-SCROLL-TESTS: suite Flutter completa validada nos checkpoints anteriores.

## Matriz 901-1400

| ID | Unidade auditavel | Referencia | Evidencia Scroll | Status | Teste/prova | Proxima acao |
|---:|---|---|---|---|---|---|
| 901 | Rota raiz representada | REF-SCROLL-SCHOOL | `/` em `simLiveRoutes` | JA EXISTIA | school_completeness | Preservar |
| 902 | Rota login representada | REF-SCROLL-SCHOOL | `/login` | JA EXISTIA | school_completeness | Preservar |
| 903 | Rota idioma representada | REF-SCROLL-SCHOOL | `/cyber/idioma` | JA EXISTIA | school_completeness | Preservar |
| 904 | Rota objetivo representada | REF-SCROLL-SCHOOL | `/cyber/objeto` | JA EXISTIA | school_completeness | Preservar |
| 905 | Rota curriculo representada | REF-SCROLL-SCHOOL | `/cyber/curriculo` | JA EXISTIA | school_completeness | Preservar |
| 906 | Rota placement representada | REF-SCROLL-SCHOOL | `/cyber/placement` | JA EXISTIA | school_completeness | Preservar |
| 907 | Rota aula representada | REF-SCROLL-SCHOOL | `/cyber/aula` | JA EXISTIA | school_completeness | Preservar |
| 908 | Rota creditos representada | REF-SCROLL-SCHOOL | `/creditos` | JA EXISTIA | school_completeness | Preservar |
| 909 | Rota checkout return representada | REF-SCROLL-SCHOOL | `/checkout/return` | JA EXISTIA | school_completeness | Preservar |
| 910 | Rota painel do pai representada | REF-SCROLL-SCHOOL | `/pai` | JA EXISTIA | school_completeness | Preservar |
| 911 | Rota privacidade representada | REF-SCROLL-SCHOOL | `/privacidade` | JA EXISTIA | school_completeness | Preservar |
| 912 | Rota termos representada | REF-SCROLL-SCHOOL | `/termos` | JA EXISTIA | school_completeness | Preservar |
| 913 | Rota deletar conta representada | REF-SCROLL-SCHOOL | `/conta/deletar` | JA EXISTIA | school_completeness | Preservar |
| 914 | API T00 mapeada como rota viva | REF-SCROLL-SCHOOL | `/api/bootstrap-t00` | JA EXISTIA | school_completeness | Preservar |
| 915 | API imagem mapeada como rota viva | REF-SCROLL-SCHOOL | `/api/generate-lesson-image` | JA EXISTIA | school_completeness | Preservar |
| 916 | API audio mapeada como rota viva | REF-SCROLL-SCHOOL | `/api/generate-lesson-audio` | JA EXISTIA | school_completeness | Preservar |
| 917 | API webhook mapeada como rota viva | REF-SCROLL-SCHOOL | `/api/public/payments/webhook` | JA EXISTIA | school_completeness | Preservar |
| 918 | API T00 marcada server-only | REF-SCROLL-SCHOOL | `serverOnly` | JA EXISTIA | school_completeness | Preservar |
| 919 | API imagem marcada server-only | REF-SCROLL-SCHOOL | `serverOnly` | JA EXISTIA | school_completeness | Preservar |
| 920 | API audio marcada server-only | REF-SCROLL-SCHOOL | `serverOnly` | JA EXISTIA | school_completeness | Preservar |
| 921 | Webhook marcado server-only | REF-SCROLL-SCHOOL | `serverOnly` | JA EXISTIA | school_completeness | Preservar |
| 922 | Ambiente portal existe | REF-SCROLL-SCHOOL | id `portal` | JA EXISTIA | school_completeness | Preservar |
| 923 | Ambiente login existe | REF-SCROLL-SCHOOL | id `login` | JA EXISTIA | school_completeness | Preservar |
| 924 | Ambiente language existe | REF-SCROLL-SCHOOL | id `language` | JA EXISTIA | school_completeness | Preservar |
| 925 | Ambiente objective existe | REF-SCROLL-SCHOOL | id `objective` | JA EXISTIA | school_completeness | Preservar |
| 926 | Ambiente preparation existe | REF-SCROLL-SCHOOL | id `preparation` | JA EXISTIA | school_completeness | Preservar |
| 927 | Ambiente placement existe | REF-SCROLL-SCHOOL | id `placement` | JA EXISTIA | school_completeness | Preservar |
| 928 | Ambiente classroom existe | REF-SCROLL-SCHOOL | id `classroom` | JA EXISTIA | school_completeness | Preservar |
| 929 | Ambiente drawer existe | REF-SCROLL-SCHOOL | id `drawer` | JA EXISTIA | school_completeness | Preservar |
| 930 | Ambiente credits existe | REF-SCROLL-SCHOOL | id `credits` | JA EXISTIA | school_completeness | Preservar |
| 931 | Ambiente checkout_return existe | REF-SCROLL-SCHOOL | id `checkout_return` | JA EXISTIA | school_completeness | Preservar |
| 932 | Ambiente father_panel existe | REF-SCROLL-SCHOOL | id `father_panel` | JA EXISTIA | school_completeness | Preservar |
| 933 | Ambiente delete_account existe | REF-SCROLL-SCHOOL | id `delete_account` | JA EXISTIA | school_completeness | Preservar |
| 934 | Ambiente privacy existe | REF-SCROLL-SCHOOL | id `privacy` | JA EXISTIA | school_completeness | Preservar |
| 935 | Ambiente terms existe | REF-SCROLL-SCHOOL | id `terms` | JA EXISTIA | school_completeness | Preservar |
| 936 | Destinos internos resolvem | REF-SCROLL-SCHOOL | `unresolvedInternalDestinations` vazio | JA EXISTIA | school_completeness | Preservar |
| 937 | Porta portal_start correta | REF-SCROLL-SCHOOL | `/cyber/idioma` | JA EXISTIA | school_completeness | Preservar |
| 938 | Porta language_known correta | REF-SCROLL-SCHOOL | `/cyber/objeto` | JA EXISTIA | school_completeness | Preservar |
| 939 | Porta objective_continue correta | REF-SCROLL-SCHOOL | `/cyber/curriculo` | JA EXISTIA | school_completeness | Preservar |
| 940 | Porta prep_to_placement correta | REF-SCROLL-SCHOOL | `/cyber/placement` | JA EXISTIA | school_completeness | Preservar |
| 941 | Porta prep_to_classroom correta | REF-SCROLL-SCHOOL | `/cyber/aula` | JA EXISTIA | school_completeness | Preservar |
| 942 | Porta placement_skip correta | REF-SCROLL-SCHOOL | `/cyber/aula` | JA EXISTIA | school_completeness | Preservar |
| 943 | Porta class_buy_credits correta | REF-SCROLL-SCHOOL | `/creditos` | JA EXISTIA | school_completeness | Preservar |
| 944 | Porta drawer_delete_account correta | REF-SCROLL-SCHOOL | `/conta/deletar` | JA EXISTIA | school_completeness | Preservar |
| 945 | Porta checkout_retry correta | REF-SCROLL-SCHOOL | `/creditos` | JA EXISTIA | school_completeness | Preservar |
| 946 | Drawer visible inicial 30 | REF-SCROLL-SCHOOL | `aulaDrawerInitialVisible` | JA EXISTIA | school_completeness | Preservar |
| 947 | Drawer page size 30 | REF-SCROLL-SCHOOL | `aulaDrawerPageSize` | JA EXISTIA | school_completeness | Preservar |
| 948 | Drawer action new_lesson | REF-SCROLL-SCHOOL | `/cyber/aula` | JA EXISTIA | school_completeness | Preservar |
| 949 | Drawer action top_up | REF-SCROLL-SCHOOL | `/creditos` | JA EXISTIA | school_completeness | Preservar |
| 950 | Drawer action open_current_lesson | REF-SCROLL-SCHOOL | `/cyber/aula` | JA EXISTIA | school_completeness | Preservar |
| 951 | Drawer action parent_panel | REF-SCROLL-SCHOOL | `/pai` | JA EXISTIA | school_completeness | Preservar |
| 952 | Drawer action privacy | REF-SCROLL-SCHOOL | `/privacidade` | JA EXISTIA | school_completeness | Preservar |
| 953 | Drawer action terms | REF-SCROLL-SCHOOL | `/termos` | JA EXISTIA | school_completeness | Preservar |
| 954 | Drawer action logout | REF-SCROLL-SCHOOL | `/login` | JA EXISTIA | school_completeness | Preservar |
| 955 | Drawer action delete_account | REF-SCROLL-SCHOOL | `/conta/deletar` | JA EXISTIA | school_completeness | Preservar |
| 956 | Drawer search acha Biologia por bio | REF-SCROLL-SCHOOL | `matchesLessonSearch` true | JA EXISTIA | school_completeness | Preservar |
| 957 | Drawer search nao acha geo indevido | REF-SCROLL-SCHOOL | `matchesLessonSearch` false | JA EXISTIA | school_completeness | Preservar |
| 958 | Completeness report completo | REF-SCROLL-SCHOOL | `report.complete true` | JA EXISTIA | school_completeness | Preservar |
| 959 | Report ambientes >=14 | REF-SCROLL-SCHOOL | `environmentCount` | JA EXISTIA | school_completeness | Preservar |
| 960 | Report portas >=50 | REF-SCROLL-SCHOOL | `doorCount` | JA EXISTIA | school_completeness | Preservar |
| 961 | Report screen routes 13 | REF-SCROLL-SCHOOL | `screenRouteCount` | JA EXISTIA | school_completeness | Preservar |
| 962 | Report API routes 4 | REF-SCROLL-SCHOOL | `apiRouteCount` | JA EXISTIA | school_completeness | Preservar |
| 963 | Report external routes 3 | REF-SCROLL-SCHOOL | `externalRouteCount` | JA EXISTIA | school_completeness | Preservar |
| 964 | Rotas mortas proibidas no report | REF-SCROLL-SCHOOL | sem unresolved | JA EXISTIA | school_completeness | Preservar |
| 965 | Server brain nao vira sala app | REF-SCROLL-SCHOOL | server-only separado | JA EXISTIA | school_completeness | Preservar |
| 966 | Segredos server nao viram app-side room | REF-SCROLL-SCHOOL | serverOnly | JA EXISTIA | school_completeness | Preservar |
| 967 | Escola tem sala de pai | REF-SCROLL-SCHOOL | father_panel | JA EXISTIA | school_completeness | Preservar |
| 968 | Escola tem privacidade | REF-SCROLL-SCHOOL | privacy | JA EXISTIA | school_completeness | Preservar |
| 969 | Escola tem termos | REF-SCROLL-SCHOOL | terms | JA EXISTIA | school_completeness | Preservar |
| 970 | Escola tem exclusao de conta | REF-SCROLL-SCHOOL | delete_account | JA EXISTIA | school_completeness | Preservar |
| 971 | Acabamento completo declarado | REF-SCROLL-FINISH | `simFinishIsComplete()` | JA EXISTIA | finish_phase | Preservar |
| 972 | Acabamento cobre todas areas | REF-SCROLL-FINISH | values length | JA EXISTIA | finish_phase | Preservar |
| 973 | Acabamento exige audio visivel | REF-SCROLL-FINISH | label audio | JA EXISTIA | finish_phase | Preservar |
| 974 | Acabamento exige imagem visivel | REF-SCROLL-FINISH | label imagem | JA EXISTIA | finish_phase | Preservar |
| 975 | Anexo objetivo usa client real | REF-SCROLL-FINISH | `SimServerAttachmentClient` | JA EXISTIA | finish_phase | Preservar |
| 976 | Anexo objetivo nao usa MOCK | REF-SCROLL-FINISH | isNot contains MOCK | JA EXISTIA | finish_phase | Preservar |
| 977 | Anexo entra processing | REF-SCROLL-FINISH | status processing | JA EXISTIA | finish_phase | Preservar |
| 978 | Anexo fica ready | REF-SCROLL-FINISH | status ready | JA EXISTIA | finish_phase | Preservar |
| 979 | Anexo preserva texto extraido | REF-SCROLL-FINISH | extractedText real | JA EXISTIA | finish_phase | Preservar |
| 980 | Anexo preserva metodo vision | REF-SCROLL-FINISH | method vision | JA EXISTIA | finish_phase | Preservar |
| 981 | Anexo envia filename real | REF-SCROLL-FINISH | `prova.pdf` | JA EXISTIA | finish_phase | Preservar |
| 982 | Anexo envia contentType real | REF-SCROLL-FINISH | `application/pdf` | JA EXISTIA | finish_phase | Preservar |
| 983 | Anexo envia bytes reais PDF | REF-SCROLL-FINISH | bytes PDF | JA EXISTIA | finish_phase | Preservar |
| 984 | Anexo registra size | REF-SCROLL-FINISH | size 8 | JA EXISTIA | finish_phase | Preservar |
| 985 | Typewriter obedece TextScaler | REF-FLUTTER-SEMANTICS | scale 28.8 | JA EXISTIA | finish_phase | Preservar |
| 986 | Typewriter usa caracteres por tick | REF-SCROLL-FINISH | `charactersPerTick: 3` | JA EXISTIA | finish_phase | Preservar |
| 987 | Typewriter usa tickDuration | REF-SCROLL-FINISH | 20ms | JA EXISTIA | finish_phase | Preservar |
| 988 | Typewriter chama onDone uma vez | REF-SCROLL-FINISH | done 1 | JA EXISTIA | finish_phase | Preservar |
| 989 | Typewriter render parcial | REF-SCROLL-FINISH | `abc` | JA EXISTIA | finish_phase | Preservar |
| 990 | Typewriter render final | REF-SCROLL-FINISH | `abcdef` | JA EXISTIA | finish_phase | Preservar |
| 991 | Aula nao mostra imagem antes de existir | REF-SCROLL-FINISH | `Imagem da aula` absent | JA EXISTIA | finish_phase | Preservar |
| 992 | Aula nao mostra audio ligado falso | REF-SCROLL-FINISH | `Audio da aula ligado` absent | JA EXISTIA | finish_phase | Preservar |
| 993 | Aula nao mostra gerar imagem falso | REF-SCROLL-FINISH | `Gerar imagem` absent | JA EXISTIA | finish_phase | Preservar |
| 994 | Tap audio sem audio real nao mostra ligado | REF-SCROLL-FINISH | absent after tap | JA EXISTIA | finish_phase | Preservar |
| 995 | Aula exibe sinal 1 apos resposta | REF-SCROLL-FINISH | `1` | JA EXISTIA | finish_phase | Preservar |
| 996 | Aula exibe sinal 2 apos resposta | REF-SCROLL-FINISH | `2` | JA EXISTIA | finish_phase | Preservar |
| 997 | Aula exibe sinal 3 apos resposta | REF-SCROLL-FINISH | `3` | JA EXISTIA | finish_phase | Preservar |
| 998 | Painel nao inventa oferta paga | REF-SCROLL-FINISH | test painel | JA EXISTIA | finish_phase | Preservar |
| 999 | Painel imagem pronta compacto | REF-SCROLL-FINISH | compact panel | JA EXISTIA | finish_phase | Preservar |
| 1000 | Painel imagem pronta notifica scroll | REF-SCROLL-FINISH | notify scroll | JA EXISTIA | finish_phase | Preservar |
| 1001 | Imagem pronta abre inspecao | REF-SCROLL-FINISH | zoom open | JA EXISTIA | finish_phase | Preservar |
| 1002 | Inspecao de imagem fecha | REF-SCROLL-FINISH | zoom close | JA EXISTIA | finish_phase | Preservar |
| 1003 | Imagem invalida erro compacto | REF-WCAG-STATUS | invalid image compact | JA EXISTIA | finish_phase | Preservar |
| 1004 | Bitmap dataUrl renderiza historico | REF-SCROLL-FINISH | dataUrl bitmap | JA EXISTIA | finish_phase | Preservar |
| 1005 | Finish cobre loading visual | REF-WCAG-STATUS | loading visual test | JA EXISTIA | finish_phase | Preservar |
| 1006 | Finish cobre erro visual | REF-WCAG-STATUS | erro visual test | JA EXISTIA | finish_phase | Preservar |
| 1007 | Finish cobre feedback | REF-SCROLL-FINISH | feedback loading/erro | JA EXISTIA | finish_phase | Preservar |
| 1008 | Finish nao abre sala falsa | REF-SCROLL-FINISH | snapshot real | JA EXISTIA | finish_phase | Preservar |
| 1009 | Finish respeita rota aula | REF-SCROLL-FINISH | session route | JA EXISTIA | finish_phase | Preservar |
| 1010 | Finish usa idioma pt | REF-SCROLL-FINISH | selectedLanguageCode pt | JA EXISTIA | finish_phase | Preservar |
| 1011 | Finish usa stableLang Portuguese | REF-SCROLL-FINISH | stableLang | JA EXISTIA | finish_phase | Preservar |
| 1012 | Finish usa objetivo salvo | REF-SCROLL-FINISH | saveObjectiveEntry true | JA EXISTIA | finish_phase | Preservar |
| 1013 | Finish abre runtime de aula | REF-SCROLL-FINISH | openAulaRuntime | JA EXISTIA | finish_phase | Preservar |
| 1014 | Finish surface mobile testada | REF-FLUTTER-SEMANTICS | Size 390x900 | JA EXISTIA | finish_phase | Preservar |
| 1015 | Finish reseta surface size | REF-FLUTTER-SEMANTICS | setSurfaceSize null | JA EXISTIA | finish_phase | Preservar |
| 1016 | Typewriter reduced motion | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Auditar disableAnimations |
| 1017 | Typewriter pause/resume | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Produto/UX |
| 1018 | Anexo cancelavel | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Cancel token |
| 1019 | Anexo progressivo | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Stream progress |
| 1020 | Inspecao imagem com teclado | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Teste teclado |
| 1021 | Audio preference default on | REF-SCROLL-MEDIA | media_phase | JA EXISTIA | media_phase | Preservar |
| 1022 | Audio preference notifica listeners | REF-SCROLL-MEDIA | media_phase | JA EXISTIA | media_phase | Preservar |
| 1023 | Audio preference persiste SharedPrefs | REF-SCROLL-MEDIA | media_phase | JA EXISTIA | media_phase | Preservar |
| 1024 | Producao usa PlatformAudioAdapter | REF-SCROLL-MEDIA | not Noop | JA EXISTIA | media_phase | Preservar |
| 1025 | Platform TTS mapeia idiomas | REF-SCROLL-MEDIA | native locales | JA EXISTIA | media_phase | Preservar |
| 1026 | Audio core cacheia gerado | REF-SCROLL-MEDIA | caches generated | JA EXISTIA | media_phase | Preservar |
| 1027 | Audio disabled pula client remoto | REF-SCROLL-MEDIA | skips generated client | JA EXISTIA | media_phase | Preservar |
| 1028 | Audio disabled pula playback local | REF-SCROLL-MEDIA | skips local playback | JA EXISTIA | media_phase | Preservar |
| 1029 | Falha playback nao chama onStart | REF-SCROLL-MEDIA | play failure | JA EXISTIA | media_phase | Preservar |
| 1030 | Falha playback nao reporta playing | REF-SCROLL-MEDIA | not report playing | JA EXISTIA | media_phase | Preservar |
| 1031 | Cache audio separa lesson | REF-SCROLL-MEDIA | cache key | JA EXISTIA | media_phase | Preservar |
| 1032 | Cache audio separa language | REF-SCROLL-MEDIA | cache key | JA EXISTIA | media_phase | Preservar |
| 1033 | Cache audio separa voice | REF-SCROLL-MEDIA | cache key | JA EXISTIA | media_phase | Preservar |
| 1034 | Cache audio separa text | REF-SCROLL-MEDIA | cache key | JA EXISTIA | media_phase | Preservar |
| 1035 | Audio remoto falha para TTS local | REF-SCROLL-MEDIA | fallback local | JA EXISTIA | media_phase | Preservar |
| 1036 | Audio remoto nao bloqueia aula | REF-SCROLL-MEDIA | without blocking lesson | JA EXISTIA | media_phase | Preservar |
| 1037 | LessonAudio preserva sequencia | REF-SCROLL-MEDIA | reading sequence | JA EXISTIA | media_phase | Preservar |
| 1038 | LessonAudio falha limpa playing | REF-SCROLL-MEDIA | clears playing | JA EXISTIA | media_phase | Preservar |
| 1039 | LessonAudio registra erro recuperavel | REF-WCAG-STATUS | recoverable error | JA EXISTIA | media_phase | Preservar |
| 1040 | Ready material prepara audioText | REF-SCROLL-MEDIA | audioText | JA EXISTIA | media_phase | Preservar |
| 1041 | Ready material nao inicia playback | REF-SCROLL-MEDIA | without starting playback | JA EXISTIA | media_phase | Preservar |
| 1042 | Doubt audio adiciona sufixo | REF-SCROLL-MEDIA | doubt suffix | JA EXISTIA | media_phase | Preservar |
| 1043 | Doubt audio respeita preferencia | REF-SCROLL-MEDIA | respects preference | JA EXISTIA | media_phase | Preservar |
| 1044 | Audio stop na selecao | REF-SCROLL-MEDIA | stop answer selection | JA EXISTIA | media_phase | Preservar |
| 1045 | Audio stop no sinal | REF-SCROLL-MEDIA | stop signal | JA EXISTIA | media_phase | Preservar |
| 1046 | Audio stop no avancar | REF-SCROLL-MEDIA | stop advance | JA EXISTIA | media_phase | Preservar |
| 1047 | Audio stop no dispose | REF-SCROLL-MEDIA | dispose paths | JA EXISTIA | media_phase | Preservar |
| 1048 | LabSession stopActiveAudio limpa playing | REF-SCROLL-MEDIA | clears playing | JA EXISTIA | media_phase | Preservar |
| 1049 | LabSession stopActiveAudio limpa loading | REF-SCROLL-MEDIA | clears loading | JA EXISTIA | media_phase | Preservar |
| 1050 | Toggle audio nao desliga preferencia | REF-SCROLL-MEDIA | does not disable preference | JA EXISTIA | media_phase | Preservar |
| 1051 | Image media event preserva cache key | REF-SCROLL-MEDIA | cache key | JA EXISTIA | media_phase | Preservar |
| 1052 | Image media event preserva item | REF-SCROLL-MEDIA | item | JA EXISTIA | media_phase | Preservar |
| 1053 | Image media event preserva layer | REF-SCROLL-MEDIA | layer | JA EXISTIA | media_phase | Preservar |
| 1054 | Visual feedback track answers | REF-SCROLL-MEDIA | learning feedback | JA EXISTIA | media_phase | Preservar |
| 1055 | Visual feedback track doubt | REF-SCROLL-MEDIA | learning feedback | JA EXISTIA | media_phase | Preservar |
| 1056 | Visual report combina funil | REF-SCROLL-MEDIA | operational report | JA EXISTIA | media_phase | Preservar |
| 1057 | Visual report combina learning | REF-SCROLL-MEDIA | operational report | JA EXISTIA | media_phase | Preservar |
| 1058 | Visual prompt preserva idioma | REF-SCROLL-MEDIA | language directive | JA EXISTIA | media_phase | Preservar |
| 1059 | Visual prompt preserva validacao | REF-SCROLL-MEDIA | image validation | JA EXISTIA | media_phase | Preservar |
| 1060 | Critico julga qualidade visual | REF-SCROLL-MEDIA | image critic | JA EXISTIA | media_phase | Preservar |
| 1061 | Critico nao julga so text count | REF-SCROLL-MEDIA | not raw text count | JA EXISTIA | media_phase | Preservar |
| 1062 | Final quality aceita SVG util | REF-SCROLL-MEDIA | accepts context | JA EXISTIA | media_phase | Preservar |
| 1063 | Final quality escala sem keys | REF-SCROLL-MEDIA | escalates ignoring keys | JA EXISTIA | media_phase | Preservar |
| 1064 | Final quality aceita simples jovem | REF-SCROLL-MEDIA | young levels | JA EXISTIA | media_phase | Preservar |
| 1065 | Final quality segue rejeicao critic | REF-SCROLL-MEDIA | critic rejection | JA EXISTIA | media_phase | Preservar |
| 1066 | Compression raster para jpeg dataUrl | REF-SCROLL-MEDIA | compression test | JA EXISTIA | media_phase | Preservar |
| 1067 | SoftwareVisualRequest contexto completo | REF-SCROLL-MEDIA | complete fields | JA EXISTIA | media_phase | Preservar |
| 1068 | Palette roles semanticos | REF-SCROLL-MEDIA | semantic roles | JA EXISTIA | media_phase | Preservar |
| 1069 | Palette contraste seguro | REF-SCROLL-MEDIA | safe contrast | JA EXISTIA | media_phase | Preservar |
| 1070 | Hierarquia visual pesos reusaveis | REF-SCROLL-MEDIA | visual weights | JA EXISTIA | media_phase | Preservar |
| 1071 | Identidade visual centralizada | REF-SCROLL-MEDIA | brand tokens | JA EXISTIA | media_phase | Preservar |
| 1072 | Nivel visual detecta perfil | REF-SCROLL-MEDIA | cognitive profiles | JA EXISTIA | media_phase | Preservar |
| 1073 | Layout visual quebra labels | REF-SCROLL-MEDIA | wraps labels | JA EXISTIA | media_phase | Preservar |
| 1074 | Layout visual espaca labels | REF-SCROLL-MEDIA | spaces labels | JA EXISTIA | media_phase | Preservar |
| 1075 | Componentes SVG bricks | REF-SCROLL-MEDIA | reusable SVG bricks | JA EXISTIA | media_phase | Preservar |
| 1076 | Palette aceita colorLegend seguro | REF-SCROLL-MEDIA | safe overrides | JA EXISTIA | media_phase | Preservar |
| 1077 | Palette rejeita colorLegend inseguro | REF-SCROLL-MEDIA | unsafe overrides | JA EXISTIA | media_phase | Preservar |
| 1078 | Flowchart usa contexto | REF-SCROLL-MEDIA | no placeholders | JA EXISTIA | media_phase | Preservar |
| 1079 | Flowchart aplica palette semantica | REF-SCROLL-MEDIA | colorLegend | JA EXISTIA | media_phase | Preservar |
| 1080 | SVG final leva identidade SIM | REF-SCROLL-MEDIA | unified identity | JA EXISTIA | media_phase | Preservar |
| 1081 | Render muda riqueza por nivel | REF-SCROLL-MEDIA | visual richness | JA EXISTIA | media_phase | Preservar |
| 1082 | Render quebra labels longos | REF-SCROLL-MEDIA | no overflow | JA EXISTIA | media_phase | Preservar |
| 1083 | Math labels compactam texto | REF-SCROLL-MEDIA | compact long text | JA EXISTIA | media_phase | Preservar |
| 1084 | Renderer ignora colorLegend invalido | REF-SCROLL-MEDIA | invalid ignored | JA EXISTIA | media_phase | Preservar |
| 1085 | Diagram renderers usam palette | REF-SCROLL-MEDIA | palette safely | JA EXISTIA | media_phase | Preservar |
| 1086 | Renderers codificam hierarquia | REF-SCROLL-MEDIA | hierarchy SVG | JA EXISTIA | media_phase | Preservar |
| 1087 | Math renderers preservam eixos | REF-SCROLL-MEDIA | axes not weakened | JA EXISTIA | media_phase | Preservar |
| 1088 | Cycle renderer usa key elements | REF-SCROLL-MEDIA | key elements | JA EXISTIA | media_phase | Preservar |
| 1089 | Comparison troca labels genericos | REF-SCROLL-MEDIA | replaces labels | JA EXISTIA | media_phase | Preservar |
| 1090 | Structure renderers usam contexto | REF-SCROLL-MEDIA | context | JA EXISTIA | media_phase | Preservar |
| 1091 | Structure renderers fallback legado | REF-SCROLL-MEDIA | legacy fallback | JA EXISTIA | media_phase | Preservar |
| 1092 | Remaining renderers trocam labels | REF-SCROLL-MEDIA | replace generic | JA EXISTIA | media_phase | Preservar |
| 1093 | Catalog seleciona programacao | REF-SCROLL-MEDIA | ProgrammingFlowRenderer | JA EXISTIA | media_phase | Preservar |
| 1094 | Catalog seleciona quimica | REF-SCROLL-MEDIA | ChemistryReactionRenderer | JA EXISTIA | media_phase | Preservar |
| 1095 | Catalog seleciona geografia | REF-SCROLL-MEDIA | GeographyLayersRenderer | JA EXISTIA | media_phase | Preservar |
| 1096 | Catalog seleciona logica | REF-SCROLL-MEDIA | LogicArgumentRenderer | JA EXISTIA | media_phase | Preservar |
| 1097 | Catalog seleciona negocios | REF-SCROLL-MEDIA | BusinessFlowRenderer | JA EXISTIA | media_phase | Preservar |
| 1098 | Existing domain engines prioridade | REF-SCROLL-MEDIA | before generic | JA EXISTIA | media_phase | Preservar |
| 1099 | Unknown domain fallback seguro | REF-SCROLL-MEDIA | generic fallback | JA EXISTIA | media_phase | Preservar |
| 1100 | Paid image dataUrl usable apenas | REF-SCROLL-MEDIA | fetch usable paid | JA EXISTIA | media_phase | Preservar |
| 1101 | Local software resolve schematic | REF-SCROLL-MEDIA | free SVG | JA EXISTIA | media_phase | Preservar |
| 1102 | Local software sem paid image | REF-SCROLL-MEDIA | without paid image | JA EXISTIA | media_phase | Preservar |
| 1103 | Escalation envia rico para N3 | REF-SCROLL-MEDIA | rich local goes n3 | JA EXISTIA | media_phase | Preservar |
| 1104 | Escalation chama N3 antes de pago | REF-SCROLL-MEDIA | n3 before paid | JA EXISTIA | media_phase | Preservar |
| 1105 | Escalation rejeita local generico | REF-SCROLL-MEDIA | generic rejected | JA EXISTIA | media_phase | Preservar |
| 1106 | N3 transport fail usa local fallback | REF-SCROLL-MEDIA | n3 fails local fallback | JA EXISTIA | media_phase | Preservar |
| 1107 | N3 SVG rejeitado por critic | REF-SCROLL-MEDIA | critic rejects n3 | JA EXISTIA | media_phase | Preservar |
| 1108 | N3 failure mantem diagnostico | REF-SCROLL-MEDIA | diagnostic reason | JA EXISTIA | media_phase | Preservar |
| 1109 | Pipeline envia contexto pedagogico N3 | REF-SCROLL-MEDIA | trigger context | JA EXISTIA | media_phase | Preservar |
| 1110 | N3 no_image sem paid offer | REF-SCROLL-MEDIA | no_image | JA EXISTIA | media_phase | Preservar |
| 1111 | Telemetry mede software rate | REF-SCROLL-MEDIA | visual funnel telemetry | JA EXISTIA | media_phase | Preservar |
| 1112 | N3 unavailable usa local antes pago | REF-SCROLL-MEDIA | deterministic local | JA EXISTIA | media_phase | Preservar |
| 1113 | Formula sem template usa SVG local | REF-SCROLL-MEDIA | before paid | JA EXISTIA | media_phase | Preservar |
| 1114 | Candidates render local se N3 off | REF-SCROLL-MEDIA | candidates local | JA EXISTIA | media_phase | Preservar |
| 1115 | N3 envia realista ambiguo a pago permitido | REF-SCROLL-MEDIA | paid allowed | JA EXISTIA | media_phase | Preservar |
| 1116 | Paid offer aceita | REF-SCROLL-MEDIA | accepts | JA EXISTIA | media_phase | Preservar |
| 1117 | Paid offer recusa | REF-SCROLL-MEDIA | declines | JA EXISTIA | media_phase | Preservar |
| 1118 | Paid offer roteia para creditos | REF-SCROLL-MEDIA | routes credits | JA EXISTIA | media_phase | Preservar |
| 1119 | PaidImageService oferta antes fetch | REF-SCROLL-MEDIA | offers before fetch | JA EXISTIA | media_phase | Preservar |
| 1120 | PaidImageService consome apos accept | REF-SCROLL-MEDIA | consumes after accept | JA EXISTIA | media_phase | Preservar |
| 1121 | PaidImageService offer id estavel | REF-SCROLL-MEDIA | stable offer | JA EXISTIA | media_phase | Preservar |
| 1122 | PaidImageService idempotency key | REF-SCROLL-MEDIA | idempotency | JA EXISTIA | media_phase | Preservar |
| 1123 | PaidImageService bloqueia double consume | REF-SCROLL-MEDIA | double consume | JA EXISTIA | media_phase | Preservar |
| 1124 | API contracts sem secrets | REF-SCROLL-MEDIA | constants without secrets | JA EXISTIA | media_phase | Preservar |
| 1125 | CompleteLesson.copyWith limpa image | REF-SCROLL-MEDIA | clear stale image | JA EXISTIA | media_phase | Preservar |
| 1126 | SVG sanitizer aceita sem viewBox | REF-SCROLL-MEDIA | valid SVG no viewBox | JA EXISTIA | media_phase | Preservar |
| 1127 | SVG sanitizer mantem security blocks | REF-SCROLL-MEDIA | security blocks | JA EXISTIA | media_phase | Preservar |
| 1128 | Visual prompt alterado? | Regra usuario | nao tocado nesta fatia | PRESERVADO | git diff | Preservar |
| 1129 | N2 alterado? | Regra usuario | nao tocado nesta fatia | PRESERVADO | git diff | Preservar |
| 1130 | N3 alterado? | Regra usuario | nao tocado nesta fatia | PRESERVADO | git diff | Preservar |
| 1131 | Credito pago alterado? | Regra usuario | nao tocado nesta fatia | PRESERVADO | git diff | Preservar |
| 1132 | Cache antigo reintroduzido? | Regra usuario | nao tocado nesta fatia | PRESERVADO | git diff | Preservar |
| 1133 | Servidor alterado? | Regra usuario | nao tocado nesta fatia | PRESERVADO | git diff | Preservar |
| 1134 | Alt text dinamico visual | REF-FLUTTER-SEMANTICS | parcial/generico | BLOQUEADO | N/A | Adicionar metadado |
| 1135 | Captions em imagem complexa | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Criar descricao longa |
| 1136 | Inspecao imagem por teclado | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Testar teclado |
| 1137 | Visual renderer benchmark | REF-SLACK-PAGINATION | nao comprovado | BLOQUEADO | N/A | Criar benchmark |
| 1138 | Visual cache metric persistida | REF-SLACK-HISTORY | telemetria parcial | BLOQUEADO | N/A | Metric store |
| 1139 | Visual retry backoff N3 | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Policy retry |
| 1140 | Visual cancelamento por rota | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Cancel token |
| 1141 | LessonMaterialCache limita 3 vivos | REF-SCROLL-READY | cache keeps three | JA EXISTIA | first_lesson_ready | Preservar |
| 1142 | Orchestrator carrega visual_trigger | REF-SCROLL-READY | carries T02 trigger | JA EXISTIA | first_lesson_ready | Preservar |
| 1143 | Orchestrator usa SVG inline | REF-SCROLL-READY | svg_inline | JA EXISTIA | first_lesson_ready | Preservar |
| 1144 | Orchestrator usa local antes pago | REF-SCROLL-READY | quadratic lesson | JA EXISTIA | first_lesson_ready | Preservar |
| 1145 | Orchestrator agenda funil fresco cache texto | REF-SCROLL-READY | cached text | JA EXISTIA | first_lesson_ready | Preservar |
| 1146 | Orchestrator render math_template | REF-SCROLL-READY | math_template | JA EXISTIA | first_lesson_ready | Preservar |
| 1147 | Orchestrator publica paid offer por key | REF-SCROLL-READY | paid offer key | JA EXISTIA | first_lesson_ready | Preservar |
| 1148 | Orchestrator reset declined offer | REF-SCROLL-READY | reset by lesson key | JA EXISTIA | first_lesson_ready | Preservar |
| 1149 | EventBus replay late offer | REF-SCROLL-READY | replays pending | JA EXISTIA | first_lesson_ready | Preservar |
| 1150 | EventBus strip image late replay | REF-SCROLL-READY | strips image | JA EXISTIA | first_lesson_ready | Preservar |
| 1151 | Review visual_trigger preservado | REF-SCROLL-READY | review requests | JA EXISTIA | first_lesson_ready | Preservar |
| 1152 | Recovery visual_trigger preservado | REF-SCROLL-READY | recovery requests | JA EXISTIA | first_lesson_ready | Preservar |
| 1153 | Background prefetch nao cria pago | REF-SCROLL-READY | no paid background | JA EXISTIA | first_lesson_ready | Preservar |
| 1154 | Dopamine engine prepara A/B/C | REF-SCROLL-READY | slots from state | JA EXISTIA | first_lesson_ready | Preservar |
| 1155 | Ready material invalido descartado | REF-SCROLL-READY | invalid discarded | JA EXISTIA | first_lesson_ready | Preservar |
| 1156 | T02 chamado apos material invalido | REF-SCROLL-READY | T02 called again | JA EXISTIA | first_lesson_ready | Preservar |
| 1157 | Window metadata espelhada | REF-SCROLL-READY | mirror metadata | JA EXISTIA | first_lesson_ready | Preservar |
| 1158 | Window nao duplica jobs ativos | REF-SCROLL-READY | active jobs | JA EXISTIA | first_lesson_ready | Preservar |
| 1159 | Persistent cache invalido ignorado | REF-SCROLL-READY | invalid persistent cache | JA EXISTIA | first_lesson_ready | Preservar |
| 1160 | Ready state agenda visual free | REF-SCROLL-READY | schedules free software | JA EXISTIA | first_lesson_ready | Preservar |
| 1161 | Cached text agenda visual free | REF-SCROLL-READY | cached text-only | JA EXISTIA | first_lesson_ready | Preservar |
| 1162 | T02 adapter prepara primeiro minimo | REF-SCROLL-READY | first minimum | JA EXISTIA | first_lesson_ready | Preservar |
| 1163 | Onboarding abre parcial e prepara B/C | REF-SCROLL-READY | first partial B/C | JA EXISTIA | first_lesson_ready | Preservar |
| 1164 | Onboarding abre antes T02 lento | REF-SCROLL-READY | slow T02 | JA EXISTIA | first_lesson_ready | Preservar |
| 1165 | Onboarding preenche apos T02 | REF-SCROLL-READY | fills after | JA EXISTIA | first_lesson_ready | Preservar |
| 1166 | Placement aparece com minimo background | REF-SCROLL-READY | placement necessary | JA EXISTIA | first_lesson_ready | Preservar |
| 1167 | Ready window com paid accepted missing pula | REF-SCROLL-READY | skip_no_offer | JA EXISTIA | first_lesson_ready | Preservar |
| 1168 | Ready window com local SVG aceita critic | REF-SCROLL-READY | critic_ok | JA EXISTIA | first_lesson_ready | Preservar |
| 1169 | Ready window final quality aceita | REF-SCROLL-READY | final accepted | JA EXISTIA | first_lesson_ready | Preservar |
| 1170 | Ready window log stage n2 | REF-SCROLL-READY | stage=n2 | JA EXISTIA | first_lesson_ready | Preservar |
| 1171 | Ready window log renderer | REF-SCROLL-READY | renderer= | JA EXISTIA | first_lesson_ready | Preservar |
| 1172 | Ready window log policy | REF-SCROLL-READY | policy= | JA EXISTIA | first_lesson_ready | Preservar |
| 1173 | Ready window retry manual UI | REF-WCAG-STATUS | parcial | BLOQUEADO | N/A | Auditar UI retry |
| 1174 | Ready window cancel token | REF-FLUTTER-SEMANTICS | nao comprovado | BLOQUEADO | N/A | Implementar contrato |
| 1175 | Ready window priority tuning dinamico | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Metric-driven policy |
| 1176 | Ready window cold start benchmark | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Benchmark |
| 1177 | Ready window memory pressure policy | REF-SLACK-HISTORY | limite 3 cache, nao geral | BLOQUEADO | N/A | Politica memoria |
| 1178 | Ready window offline mode | REF-SLACK-HISTORY | parcial cache | BLOQUEADO | N/A | Offline contract |
| 1179 | Ready window error budget | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Observability |
| 1180 | Ready window per-user metrics | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Metric store |
| 1181 | Cloud progress escolhe mais avancado | REF-SCROLL-CLOUD | progress service | JA EXISTIA | cloud_phase | Preservar |
| 1182 | Supabase cloud storage load auth | REF-SCROLL-CLOUD | authenticated session | JA EXISTIA | cloud_phase | Preservar |
| 1183 | Supabase cloud storage persist auth | REF-SCROLL-CLOUD | authenticated session | JA EXISTIA | cloud_phase | Preservar |
| 1184 | Cloud queue merge remote rejected | REF-SCROLL-CLOUD | cloud queue | JA EXISTIA | cloud_phase | Preservar |
| 1185 | Cloud client envia bearer | REF-SCROLL-CLOUD | electrical | JA EXISTIA | electrical | Preservar |
| 1186 | Cloud client envia state completo | REF-SCROLL-CLOUD | body state | JA EXISTIA | electrical | Preservar |
| 1187 | Cloud client highWaterMark | REF-SCROLL-CLOUD | highWaterMark | JA EXISTIA | electrical | Preservar |
| 1188 | Backup import Web retoma ponto | REF-SCROLL-CLOUD | simweb backup | JA EXISTIA | sync_b | Preservar |
| 1189 | Backup app roundtrip sem perda | REF-SCROLL-CLOUD | roundtrip | JA EXISTIA | sync_b | Preservar |
| 1190 | Multi-device converge dois dispositivos | REF-SCROLL-CLOUD | multi_device | JA EXISTIA | sync_b | Preservar |
| 1191 | Cloud delete lesson contract | REF-SCROLL-CLOUD | cloud functions fake | JA EXISTIA | sync_b | Preservar |
| 1192 | Cloud list states contract | REF-SCROLL-CLOUD | listStudentStates | JA EXISTIA | sync_b | Preservar |
| 1193 | Cloud list summaries contract | REF-SCROLL-CLOUD | listStudentStateSummaries | JA EXISTIA | sync_b | Preservar |
| 1194 | Cloud persist result contract | REF-SCROLL-CLOUD | PersistStudentStateResult | JA EXISTIA | sync_b | Preservar |
| 1195 | Cloud syncStatus pending | REF-SCROLL-CLOUD | syncStatus pending | JA EXISTIA | sync_b | Preservar |
| 1196 | Cloud syncInfo Web mirror | REF-SCROLL-CLOUD | webState syncInfo | JA EXISTIA | sync_b | Preservar |
| 1197 | Cloud schema migration antiga | REF-SLACK-HISTORY | parcial | BLOQUEADO | N/A | Criar migrations |
| 1198 | Cloud conflito manual UI | REF-SLACK-HISTORY | motor resolve, UI nao | BLOQUEADO | N/A | UX conflito |
| 1199 | Cloud encryption at rest local | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Security |
| 1200 | Cloud purge LGPD universal | REF-SLACK-HISTORY | delete account parcial | BLOQUEADO | N/A | Legal/security |
| 1201 | External T00 porta viva | REF-SCROLL-TESTS | bootstrap-t00 | JA EXISTIA | external_ai | Preservar |
| 1202 | External T00 bearer | REF-SCROLL-TESTS | tokenPresent true | JA EXISTIA | external_ai | Preservar |
| 1203 | External image endpoint | REF-SCROLL-TESTS | generate image | JA EXISTIA | external_ai | Preservar |
| 1204 | External image sem provider key | REF-SCROLL-TESTS | no provider key | JA EXISTIA | external_ai | Preservar |
| 1205 | External image metadata success | REF-SCROLL-TESTS | metadata | JA EXISTIA | external_ai | Preservar |
| 1206 | External visual-route endpoint | REF-SCROLL-TESTS | visual-route | JA EXISTIA | external_ai | Preservar |
| 1207 | External visual SVG free | REF-SCROLL-TESTS | SVG gratuito | JA EXISTIA | external_ai | Preservar |
| 1208 | External visual no_image N3 | REF-SCROLL-TESTS | no_image | JA EXISTIA | external_ai | Preservar |
| 1209 | External audio endpoint | REF-SCROLL-TESTS | generate lesson audio | JA EXISTIA | external_ai | Preservar |
| 1210 | External audio dataUrl | REF-SCROLL-TESTS | dataUrl | JA EXISTIA | external_ai | Preservar |
| 1211 | External image error status | REF-SCROLL-TESTS | status | JA EXISTIA | external_ai | Preservar |
| 1212 | External image error requestId | REF-SCROLL-TESTS | requestId | JA EXISTIA | external_ai | Preservar |
| 1213 | External image error code | REF-SCROLL-TESTS | code | JA EXISTIA | external_ai | Preservar |
| 1214 | External image error retryable | REF-SCROLL-TESTS | retryable | JA EXISTIA | external_ai | Preservar |
| 1215 | External audio error requestId | REF-SCROLL-TESTS | requestId | JA EXISTIA | external_ai | Preservar |
| 1216 | External audio timeout retryable | REF-SCROLL-TESTS | retryable timeout | JA EXISTIA | external_ai | Preservar |
| 1217 | External audio timeout client id | REF-SCROLL-TESTS | client requestId | JA EXISTIA | external_ai | Preservar |
| 1218 | External T02 no fake route | REF-SCROLL-TESTS | nao inventa rota | JA EXISTIA | external_ai | Preservar |
| 1219 | External T02 bridge configured | REF-SCROLL-TESTS | usa ponte | JA EXISTIA | external_ai | Preservar |
| 1220 | External T02 invalid no fake lesson | REF-SCROLL-TESTS | nao vira aula falsa | JA EXISTIA | external_ai | Preservar |
| 1221 | External T02 invalid no default A | REF-SCROLL-TESTS | sem default A | JA EXISTIA | external_ai | Preservar |
| 1222 | External attachment endpoint | REF-SCROLL-FINISH | process attachment | JA EXISTIA | electrical/finish | Preservar |
| 1223 | External attachment requestId error | REF-SCROLL-FINISH | rid-body | JA EXISTIA | electrical | Preservar |
| 1224 | External payments endpoint | REF-SCROLL-FINISH | payments route | JA EXISTIA | electrical | Preservar |
| 1225 | External checkout sends only packId | REF-SCROLL-FINISH | no amount | JA EXISTIA | electrical | Preservar |
| 1226 | External delete account auth | REF-SCROLL-FINISH | endpoint autenticado | JA EXISTIA | electrical | Preservar |
| 1227 | External storage no secret | REF-SCROLL-FINISH | sem secret | JA EXISTIA | electrical | Preservar |
| 1228 | External transport timeout policy global | REF-SLACK-HISTORY | tempos locais, nao policy unificada | BLOQUEADO | N/A | Unificar |
| 1229 | External retry policy global | REF-SLACK-HISTORY | parcial | BLOQUEADO | N/A | Backoff |
| 1230 | External circuit breaker | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Reliability |
| 1231 | Billing pricing currency BRL | REF-SCROLL-TESTS | simPricing | JA EXISTIA | billing_phase | Preservar |
| 1232 | Billing lesson cost 3 | REF-SCROLL-TESTS | lessonCostCredits | JA EXISTIA | billing_phase | Preservar |
| 1233 | Billing image cost 10 | REF-SCROLL-TESTS | imageCostCredits | JA EXISTIA | billing_phase | Preservar |
| 1234 | Billing signup bonus 9 | REF-SCROLL-TESTS | signupBonus | JA EXISTIA | billing_phase | Preservar |
| 1235 | Billing pack credits_100 price | REF-SCROLL-TESTS | 790 | JA EXISTIA | billing_phase | Preservar |
| 1236 | Billing pack credits_200 credits | REF-SCROLL-TESTS | 200 | JA EXISTIA | billing_phase | Preservar |
| 1237 | Billing pack credits_500 price | REF-SCROLL-TESTS | 3950 | JA EXISTIA | billing_phase | Preservar |
| 1238 | Play product 100 stable | REF-SCROLL-TESTS | sim_credits_100 | JA EXISTIA | billing_phase | Preservar |
| 1239 | Play product 200 stable | REF-SCROLL-TESTS | sim_credits_200 | JA EXISTIA | billing_phase | Preservar |
| 1240 | Play product 500 stable | REF-SCROLL-TESTS | sim_credits_500 | JA EXISTIA | billing_phase | Preservar |
| 1241 | Return store safe internal | REF-SCROLL-TESTS | `/cyber/aula` | JA EXISTIA | billing_phase | Preservar |
| 1242 | Return store rejects evil URL | REF-SCROLL-TESTS | `//evil.com` | JA EXISTIA | billing_phase | Preservar |
| 1243 | Return store rejects creditos | REF-SCROLL-TESTS | `/creditos` | JA EXISTIA | billing_phase | Preservar |
| 1244 | Hosted checkout Stripe URL | REF-SCROLL-TESTS | checkout stripe | JA EXISTIA | billing_phase | Preservar |
| 1245 | Embedded checkout rollback | REF-SCROLL-TESTS | embedded | JA EXISTIA | billing_phase | Preservar |
| 1246 | Checkout return confirms session | REF-SCROLL-TESTS | confirm | JA EXISTIA | billing_phase | Preservar |
| 1247 | Webhook paid grants official pack | REF-SCROLL-TESTS | paid grant | JA EXISTIA | billing_phase | Preservar |
| 1248 | Webhook unpaid ignored | REF-SCROLL-TESTS | unpaid null | JA EXISTIA | billing_phase | Preservar |
| 1249 | Account deletion exact phrase | REF-SCROLL-TESTS | DELETAR | JA EXISTIA | billing_phase | Preservar |
| 1250 | Lab billing Google Play prod | REF-SCROLL-TESTS | Play flow | JA EXISTIA | billing_phase | Preservar |
| 1251 | Lab billing auth missing no start | REF-SCROLL-TESTS | auth missing | JA EXISTIA | billing_phase | Preservar |
| 1252 | Billing pending state surfaced | REF-SCROLL-TESTS | pending | JA EXISTIA | billing_phase | Preservar |
| 1253 | Billing canceled state surfaced | REF-SCROLL-TESTS | canceled | JA EXISTIA | billing_phase | Preservar |
| 1254 | Charge input normalizes ids | REF-SCROLL-TESTS | server validator | JA EXISTIA | billing_phase | Preservar |
| 1255 | Billing restore purchases | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Play restore |
| 1256 | Billing receipt validation local UI | REF-SLACK-HISTORY | server/Play parcial | BLOQUEADO | N/A | Produto |
| 1257 | Billing fraud telemetry | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Observability |
| 1258 | Billing family sharing rules | REF-SLACK-HISTORY | nao aplicavel atual | NAO APLICAVEL | N/A | Reavaliar produto |
| 1259 | Billing subscription plan | REF-SLACK-HISTORY | nao aplicavel credit pack | NAO APLICAVEL | N/A | Reavaliar produto |
| 1260 | Billing refund automation | REF-SLACK-HISTORY | parcial paid image | BLOQUEADO | N/A | Contrato |
| 1261 | Runtime route aula chat default | REF-SCROLL-TESTS | widget route | JA EXISTIA | widget_test | Preservar |
| 1262 | Runtime route sem id volta objetivo | REF-SCROLL-TESTS | no lesson id | JA EXISTIA | widget_test | Preservar |
| 1263 | Runtime objective launch T00 | REF-SCROLL-TESTS | t00 called | JA EXISTIA | widget_test | Preservar |
| 1264 | Runtime objective launch T02 | REF-SCROLL-TESTS | t02 called | JA EXISTIA | widget_test | Preservar |
| 1265 | Runtime normal flow 3x3 completion | REF-SCROLL-TESTS | normal full flow | JA EXISTIA | normal_flow | Preservar |
| 1266 | Runtime L1 correct -> L3 | REF-SCROLL-TESTS | T01 | JA EXISTIA | classroom_parity | Preservar |
| 1267 | Runtime L1 wrong -> L2 | REF-SCROLL-TESTS | T02 | JA EXISTIA | classroom_parity | Preservar |
| 1268 | Runtime L3 correct -> next item | REF-SCROLL-TESTS | T03 | JA EXISTIA | classroom_parity | Preservar |
| 1269 | Runtime L3 signal3 reinforce | REF-SCROLL-TESTS | T04 | JA EXISTIA | classroom_parity | Preservar |
| 1270 | Runtime signal2 L1 -> L2 | REF-SCROLL-TESTS | T05 | JA EXISTIA | classroom_parity | Preservar |
| 1271 | Runtime signal2 L2 -> L3 | REF-SCROLL-TESTS | T06 | JA EXISTIA | classroom_parity | Preservar |
| 1272 | Runtime wrong L2 signal3 reinforce | REF-SCROLL-TESTS | T07 | JA EXISTIA | classroom_parity | Preservar |
| 1273 | Runtime final item completion | REF-SCROLL-TESTS | T08 | JA EXISTIA | classroom_parity | Preservar |
| 1274 | Runtime out of range completion | REF-SCROLL-TESTS | T09 | JA EXISTIA | classroom_parity | Preservar |
| 1275 | Runtime invalid layer current | REF-SCROLL-TESTS | T10 | JA EXISTIA | classroom_parity | Preservar |
| 1276 | Runtime empty curriculum no decision | REF-SCROLL-TESTS | T11 | JA EXISTIA | classroom_parity | Preservar |
| 1277 | Runtime completed marker advances | REF-SCROLL-TESTS | T12 | JA EXISTIA | classroom_parity | Preservar |
| 1278 | Runtime mainAdvances counts | REF-SCROLL-TESTS | T13 | JA EXISTIA | classroom_parity | Preservar |
| 1279 | Runtime correctAnswer fallback explicit | REF-SCROLL-TESTS | T14 | JA EXISTIA | classroom_parity | Preservar |
| 1280 | Runtime history image preserve 5 | REF-SCROLL-TESTS | T15 | JA EXISTIA | classroom_parity | Preservar |
| 1281 | Runtime queue debounce | REF-SCROLL-TESTS | T16 | JA EXISTIA | classroom_parity | Preservar |
| 1282 | Runtime queue retains failure | REF-SCROLL-TESTS | T17 | JA EXISTIA | classroom_parity | Preservar |
| 1283 | Runtime queue merge remote reject | REF-SCROLL-TESTS | T18 | JA EXISTIA | classroom_parity | Preservar |
| 1284 | Runtime queue max attempts | REF-SCROLL-TESTS | T19 | JA EXISTIA | classroom_parity | Preservar |
| 1285 | Runtime lifecycle drains queue | REF-SCROLL-TESTS | T20 | JA EXISTIA | classroom_parity | Preservar |
| 1286 | Runtime material mismatch null | REF-SCROLL-TESTS | T21 | JA EXISTIA | classroom_parity | Preservar |
| 1287 | Runtime material match returns | REF-SCROLL-TESTS | T22 | JA EXISTIA | classroom_parity | Preservar |
| 1288 | Runtime ready window 3 slots | REF-SCROLL-TESTS | T23 | JA EXISTIA | classroom_parity | Preservar |
| 1289 | Runtime answer stops audio | REF-SCROLL-TESTS | T24 | JA EXISTIA | classroom_parity | Preservar |
| 1290 | Runtime signal ignored in loading | REF-SCROLL-TESTS | T25 | JA EXISTIA | classroom_parity | Preservar |
| 1291 | Runtime delayed signal ignored | REF-SCROLL-TESTS | T25b | JA EXISTIA | classroom_parity | Preservar |
| 1292 | Runtime advance ignored no signal | REF-SCROLL-TESTS | T26 | JA EXISTIA | classroom_parity | Preservar |
| 1293 | Runtime completion once | REF-SCROLL-TESTS | T27 | JA EXISTIA | classroom_parity | Preservar |
| 1294 | Runtime stableHash ignores metadata | REF-SCROLL-TESTS | T28 | JA EXISTIA | classroom_parity | Preservar |
| 1295 | Runtime branch/fork response | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Produto |
| 1296 | Runtime regenerate question | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Pedagogia |
| 1297 | Runtime stop generation T02 | REF-TELEGRAM-ACTION | nao comprovado | BLOQUEADO | N/A | Cancel token |
| 1298 | Runtime edit answer after send | REF-SLACK-HISTORY | nao aplicavel pedagogia atual | NAO APLICAVEL | N/A | Reavaliar |
| 1299 | Runtime reactions social | REF-SLACK-HISTORY | nao aplicavel aula individual | NAO APLICAVEL | N/A | Reavaliar |
| 1300 | Runtime collaborative multiuser | REF-SLACK-HISTORY | nao aplicavel atual | NAO APLICAVEL | N/A | Reavaliar |
| 1301 | Accessibility touch height primary | REF-FLUTTER-SEMANTICS | sim ideal layout | JA EXISTIA | sim_ideal_layout | Preservar |
| 1302 | Accessibility touch height secondary | REF-FLUTTER-SEMANTICS | sim ideal layout | JA EXISTIA | sim_ideal_layout | Preservar |
| 1303 | Tablet learning column wider | REF-FLUTTER-SEMANTICS | CyberStepShell | JA EXISTIA | sim_ideal_layout | Preservar |
| 1304 | Phone breakpoint focused | REF-FLUTTER-SEMANTICS | breakpoints | JA EXISTIA | sim_ideal_layout | Preservar |
| 1305 | Classroom text scale phone | REF-FLUTTER-SEMANTICS | text scale | JA EXISTIA | sim_ideal_layout | Preservar |
| 1306 | Classroom text scale tablet | REF-FLUTTER-SEMANTICS | text scale | JA EXISTIA | sim_ideal_layout | Preservar |
| 1307 | Audio bubble semantics real only | REF-FLUTTER-SEMANTICS | health test | JA EXISTIA | classroom_health | Preservar |
| 1308 | User can scroll back theory | REF-FLUTTER-SEMANTICS | health test | JA EXISTIA | classroom_health | Preservar |
| 1309 | Tablet side rail no duplicate font | REF-FLUTTER-SEMANTICS | health test | JA EXISTIA | classroom_health | Preservar |
| 1310 | Passive update no scroll theft | REF-FLUTTER-SEMANTICS | health test | JA EXISTIA | classroom_health | Preservar |
| 1311 | Return current after passive update | REF-FLUTTER-SEMANTICS | health test | JA EXISTIA | classroom_health | Preservar |
| 1312 | High zoom signals visible | REF-FLUTTER-SEMANTICS | health test | JA EXISTIA | classroom_health | Preservar |
| 1313 | High zoom feedback visible | REF-FLUTTER-SEMANTICS | health test | JA EXISTIA | classroom_health | Preservar |
| 1314 | High zoom advance visible | REF-FLUTTER-SEMANTICS | health test | JA EXISTIA | classroom_health | Preservar |
| 1315 | Signals drawer below active option | REF-FLUTTER-SEMANTICS | health test | JA EXISTIA | classroom_health | Preservar |
| 1316 | Image space reserved | REF-FLUTTER-SEMANTICS | health test | JA EXISTIA | classroom_health | Preservar |
| 1317 | Image ready shown | REF-FLUTTER-SEMANTICS | health test | JA EXISTIA | classroom_health | Preservar |
| 1318 | Font control five levels | REF-FLUTTER-SEMANTICS | health test | JA EXISTIA | classroom_health | Preservar |
| 1319 | Font control persists | REF-FLUTTER-SEMANTICS | health test | JA EXISTIA | classroom_health | Preservar |
| 1320 | Reduce motion all animations | REF-FLUTTER-SEMANTICS | parcial | BLOQUEADO | N/A | Auditar animacoes |
| 1321 | Chat timeline renders callbacks | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1322 | Chat signal callbacks | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1323 | Chat retry action | REF-WCAG-STATUS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1324 | Chat delivery semantics | REF-WCAG-STATUS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1325 | Chat live region semantics | REF-WCAG-STATUS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1326 | Chat feedback advance action | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1327 | Chat reader scroll preserved | REF-FLUTTER-SEMANTICS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1328 | Chat return current | REF-FLUTTER-SEMANTICS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1329 | Chat delivery status update | REF-WHATSAPP-TYPING | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1330 | Chat doubt action callback | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1331 | Chat image media states | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1332 | Chat history image own lesson | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1333 | Chat question visible while image loads | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1334 | Chat transcript previous messages | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1335 | Chat transient loading transcript | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1336 | Chat repeated doubt new turns | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1337 | Chat advance disabled while doubt processing | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1338 | Chat audio bubble stop tap | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1339 | Chat menu credits preserved | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1340 | Chat menu dark mode preserved | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1341 | Chat menu font scale preserved | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1342 | Chat shared doubt text/photo | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1343 | Chat normal flow feedback | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1344 | Chat current review room returns | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1345 | Chat current recovery room returns | REF-SCROLL-TESTS | chat widget | JA EXISTIA | chat_widgets | Preservar |
| 1346 | Chat search inside transcript | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Criar busca |
| 1347 | Chat jump to message by id | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Ancora |
| 1348 | Chat export transcript | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Produto |
| 1349 | Chat delete one message | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Sync model |
| 1350 | Chat edit message | REF-SLACK-HISTORY | nao aplicavel pedagogia atual | NAO APLICAVEL | N/A | Reavaliar |
| 1351 | Security no LOVABLE_API_KEY attachment | REF-SCROLL-TESTS | electrical | JA EXISTIA | electrical | Preservar |
| 1352 | Security no provider key image | REF-SCROLL-TESTS | external_ai | JA EXISTIA | external_ai | Preservar |
| 1353 | Security release cleartext false | REF-SCROLL-TESTS | electrical | JA EXISTIA | electrical | Preservar |
| 1354 | Security debug cleartext isolated | REF-SCROLL-TESTS | electrical | JA EXISTIA | electrical | Preservar |
| 1355 | Security account delete confirmation | REF-SCROLL-TESTS | billing | JA EXISTIA | billing_phase | Preservar |
| 1356 | Security safe return URL | REF-SCROLL-TESTS | billing | JA EXISTIA | billing_phase | Preservar |
| 1357 | Security bearer for cloud sync | REF-SCROLL-TESTS | electrical | JA EXISTIA | electrical | Preservar |
| 1358 | Security bearer for attachment | REF-SCROLL-TESTS | electrical | JA EXISTIA | electrical | Preservar |
| 1359 | Security logs redact objective | REF-SLACK-HISTORY | nao auditado completo | BLOQUEADO | N/A | Log audit |
| 1360 | Security PII deletion full cascade | REF-SLACK-HISTORY | parcial account delete | BLOQUEADO | N/A | Legal/backend |
| 1361 | Docs checkpoint 001-200 existe | REF-SCROLL-TESTS | doc anterior | JA EXISTIA | rg count | Preservar |
| 1362 | Docs checkpoint 201-500 existe | REF-SCROLL-TESTS | doc anterior | JA EXISTIA | rg count | Preservar |
| 1363 | Docs checkpoint 501-900 existe | REF-SCROLL-TESTS | doc anterior | JA EXISTIA | rg count | Preservar |
| 1364 | Docs checkpoint 901-1400 criado | REF-SCROLL-TESTS | este arquivo | CRIADO | rg count | Preservar |
| 1365 | Total acumulado 1400 documentado | REF-SCROLL-TESTS | header | CRIADO | rg count | Continuar |
| 1366 | Percentual 35 documentado | REF-SCROLL-TESTS | 1400/4000 | CRIADO | rg count | Continuar |
| 1367 | Bloqueios da fatia documentados | REF-WCAG-STATUS | secao bloqueios | CRIADO | revisao doc | Preservar |
| 1368 | Confirmacoes proibicoes documentadas | Regra usuario | secao confirmacoes | CRIADO | revisao doc | Preservar |
| 1369 | Nenhum item 901-1400 sem status | Regra usuario | tabela completa | CRIADO | rg status | Preservar |
| 1370 | Relatorio usa referencias explicitas | Regra usuario | referencias | CRIADO | revisao doc | Preservar |
| 1371 | Teste analyze planejado | REF-SCROLL-TESTS | validacao pos-doc | CRIADO | flutter analyze | Executar |
| 1372 | Teste focado planejado | REF-SCROLL-TESTS | areas cobertas | CRIADO | flutter test focado | Executar |
| 1373 | Teste completo planejado | REF-SCROLL-TESTS | suite completa | CRIADO | flutter test | Executar |
| 1374 | Prompt inalterado nesta fatia | Regra usuario | nenhum prompt tocado | PRESERVADO | git diff | Preservar |
| 1375 | Servidor inalterado nesta fatia | Regra usuario | nenhum backend tocado | PRESERVADO | git diff | Preservar |
| 1376 | Creditos inalterados nesta fatia | Regra usuario | billing audit-only | PRESERVADO | git diff | Preservar |
| 1377 | Cache inalterado nesta fatia | Regra usuario | doc-only | PRESERVADO | git diff | Preservar |
| 1378 | Funil pago inalterado nesta fatia | Regra usuario | doc-only | PRESERVADO | git diff | Preservar |
| 1379 | N2 preservado nesta fatia | Regra usuario | doc-only | PRESERVADO | git diff | Preservar |
| 1380 | N3 preservado nesta fatia | Regra usuario | doc-only | PRESERVADO | git diff | Preservar |
| 1381 | Busca universal pendente | REF-SLACK-HISTORY | nao implementado | BLOQUEADO | N/A | Futuro 1401+ |
| 1382 | Threads universais pendentes | REF-SLACK-HISTORY | nao implementado | BLOQUEADO | N/A | Futuro 1401+ |
| 1383 | Push notifications pendente | REF-SLACK-HISTORY | nao implementado | BLOQUEADO | N/A | Produto |
| 1384 | Offline queue universal pendente | REF-SLACK-HISTORY | parcial cloud | BLOQUEADO | N/A | Futuro |
| 1385 | Rich markdown seguro pendente | REF-SLACK-HISTORY | nao implementado universal | BLOQUEADO | N/A | Renderer |
| 1386 | Table renderer textual pendente | REF-SLACK-HISTORY | visual existe, chat nao | BLOQUEADO | N/A | Renderer chat |
| 1387 | Code block renderer pendente | REF-SLACK-HISTORY | nao implementado | BLOQUEADO | N/A | Renderer chat |
| 1388 | Formula renderer textual pendente | REF-SLACK-HISTORY | visual/math parcial | BLOQUEADO | N/A | Renderer chat |
| 1389 | Mention system pendente | REF-SLACK-HISTORY | nao aplicavel | NAO APLICAVEL | N/A | Reavaliar |
| 1390 | Multiuser presence pendente | REF-WHATSAPP-TYPING | nao aplicavel | NAO APLICAVEL | N/A | Reavaliar |
| 1391 | Per-message read receipt remoto | REF-WHATSAPP-TYPING | local parcial | BLOQUEADO | N/A | Persistir leitura |
| 1392 | Per-message delivery remoto | REF-WHATSAPP-TYPING | local parcial | BLOQUEADO | N/A | Persistir entrega |
| 1393 | Reconnect indicator global | REF-SLACK-HISTORY | nao comprovado | BLOQUEADO | N/A | Connectivity |
| 1394 | Rate-limit UI global | REF-SLACK-HISTORY | parcial errors | BLOQUEADO | N/A | Error taxonomy |
| 1395 | Background sync indicator | REF-SLACK-HISTORY | parcial syncStatus | BLOQUEADO | N/A | UI sync |
| 1396 | Full audit not exhausted | Regra usuario | ainda ha categorias | BLOQUEADO | N/A | Continuar |
| 1397 | Itens 1401-1900 pendentes | Regra usuario | proxima fatia | BLOQUEADO | N/A | Continuar |
| 1398 | Itens 1901-2400 pendentes | Regra usuario | futura fatia | BLOQUEADO | N/A | Continuar |
| 1399 | Itens 2401-4000 pendentes | Regra usuario | futuras fatias | BLOQUEADO | N/A | Continuar |
| 1400 | Exaustao estrutural ainda nao atingida | Regra usuario | 1400/4000 | BLOQUEADO | N/A | Continuar |

## Bloqueios documentados

Os bloqueios desta fatia concentram-se em busca universal, threads, push notifications, offline queue completa, renderizacao rica textual segura, presenca multiusuario, read receipts remotos, metric store, cancelamento async, seguranca profunda de logs/PII e areas futuras da propria meta. Esses itens nao foram implementados porque exigem produto, backend, storage, seguranca, UX nova ou contrato que nao pode ser introduzido sem autorizacao especifica.

## Confirmacoes

- Nenhum prompt foi alterado nesta fatia.
- Nenhum servidor/backend foi alterado nesta fatia.
- Nenhum credito, preco, cobranca ou funil pago foi alterado nesta fatia.
- Nenhum cache proibido ou reaproveitamento de imagem antiga foi reintroduzido nesta fatia.
- N2/N3 foram preservados.
- O total formal acumulado agora e 1400 itens classificados.
