# AudioID — interface graphique

**AudioID — Acoustic Fingerprinting & Music Recognition**
Interface MATLAB du système de reconnaissance musicale par empreintes audio
(ESIEE Paris, traitement du signal, E4 2026-2027).

L'interface est une couche de présentation. Elle appelle le pipeline existant

```matlab
[result, diag] = recognize_query(x, Fs, index, cfg);
```

sans réimplémenter ni modifier aucun algorithme de `src/`. Le seuil de
décision est celui de la configuration sauvegardée (`cfg.decision.threshold`,
22 votes). Il n'est jamais redéfini par l'interface.

---

## 1. Lancement

Prérequis : MATLAB R2020b ou plus récent (`uifigure`, `uigridlayout`,
`exportapp`, `xline`/`yline`). Aucune toolbox n'est requise, ni la Signal
Processing Toolbox ni une autre, et aucune connexion Internet.

Depuis la racine du projet :

```matlab
addpath('gui');
app = AudioID;
```

Au démarrage :

1. `results/fingerprint_index.mat` (variables `index`, `cfg`, `audio_files`)
   est chargé **une seule fois**, avec une fenêtre de progression ;
2. `data/metadata.csv` est lu et vérifié, puis attaché **en mémoire** à
   `index.metadata`. Aucun fichier MAT n'est écrit et l'index n'est pas
   reconstruit.

Options :

```matlab
app = AudioID('IndexFile', 'chemin/vers/autre_index.mat');
app = AudioID('MetadataFile', 'chemin/vers/metadata.csv');
app = AudioID('Visible', 'off');   % utilisé par les tests automatiques
```

### Si l'index est absent

Le fichier MAT (environ 300 Mo) est exclu de Git. L'interface s'ouvre
quand même, affiche « Index introuvable » et donne la procédure de
reconstruction dans l'onglet **Système**. Les commandes sont à exécuter
depuis la racine du projet, dans la même session MATLAB :

```matlab
run('experiments/setup_database.m')      % construction de l'index (fma_small)
run('experiments/create_queries.m')      % génération des requêtes
run('experiments/calibrate_threshold.m') % calibration de cfg.decision.threshold
save('results/fingerprint_index.mat', 'index', 'cfg', 'audio_files', '-v7.3')
```

---

## 2. Métadonnées

Fichier attendu : `data/metadata.csv`, avec les colonnes
`song_id,title,artist,duration_s,file,set,source,licence,fma_id,genre`.
Seules `song_id` et `title` sont obligatoires ; `artist`, `genre`,
`fma_id`, `file` et `duration_s` sont utilisées si elles sont présentes.

### Vérifications effectuées au démarrage

| Contrôle | Règle |
|---|---|
| Identifiant interne | `song_id` entier, unique, compris entre 1 et `numel(audio_files)` |
| Identifiant FMA | `fma_id` = numéro du fichier `audio_files{song_id}` (ex. `000213.mp3` → 213) |
| Fichier audio | nom de fichier de la colonne `file` = nom de `audio_files{song_id}` |
| Couverture | chaque morceau de la bibliothèque possède une ligne validée |

Une ligne qui échoue à un contrôle est **écartée** : le morceau reste
reconnu, mais son titre, son artiste et son genre ne sont pas affichés
(« Titre non disponible »). Si la colonne `file` suit une autre convention
de nommage pour **toutes** les lignes, le contrôle est jugé non concluant et
seul `fma_id` est utilisé.

| État affiché (onglet Système) | Situation |
|---|---|
| `100/100 morceaux vérifiés (song_id, fma_id, fichier)` | Toutes les lignes sont cohérentes |
| `Partielles : n/100 morceaux validés` | Certaines lignes sont rejetées ; leur liste figure dans les notes |
| `Incompatibles avec l'index` | Aucune ligne cohérente |
| `Illisibles` | Fichier illisible, ou colonnes `song_id` / `title` absentes |
| `Absentes` | `data/metadata.csv` introuvable |

Dans les trois derniers cas, un avertissement non bloquant s'affiche à
l'ouverture et l'interface reste pleinement utilisable.

La table en mémoire contient une ligne par `song_id` (la ligne *k*
correspond au morceau *k*). C'est le format lu par `classify_match.m` pour
renseigner `result.title`. Les métadonnées n'interviennent **pas** dans le
calcul des scores (voir le test 14).

Exemple : le morceau n°19 est affiché « **Boute** », artiste **Au**, genre
**Pop**, identifiant `#19 · FMA 213`, fichier de référence `000213.mp3`.

---

## 3. Fonctionnalités

### En-tête
- Nom, sous-titre et pastille graphique originale.
- Indicateur d'état de la bibliothèque.
- **Changer d'index…** et **Exporter PNG** (capture de la fenêtre avec
  `exportapp`, pour le rapport).

### Reconnaissance depuis un fichier
- Tous les formats lus par `audioread` sont acceptés. L'interface affiche le
  nom, la durée, la fréquence d'échantillonnage et le nombre de canaux.
- Un fichier illisible, vide, silencieux ou trop court (moins de 1 s) est
  refusé. Un extrait de moins de 3 s est signalé.
- Si la sélection est annulée, la sélection précédente est conservée.

### Reconnaissance depuis le microphone
- Durée de 3, 5 ou 10 s ; barre de progression ; bouton **Arrêter**.
- Un nouvel `audiorecorder` est créé à chaque acquisition, puis **libéré**
  (callbacks retirés, arrêt, `delete`) après un succès, une annulation, une
  erreur, ou à la fermeture de la fenêtre. Plusieurs enregistrements
  successifs sont donc possibles.
- Au lancement d'une acquisition, la carte résultat et les graphiques de
  l'analyse précédente sont effacés : aucun ancien nom de fichier ne reste
  affiché pendant l'écoute.
- Les erreurs renvoyées par le périphérique (par exemple
  `Device Error: Internal Device error`) sont affichées **telles quelles**.
  Le message rappelle qu'elles peuvent survenir indépendamment d'AudioID, et
  indique comment le vérifier (`audiorecorder` seul) et comment rétablir le
  service audio (`sudo killall coreaudiod`).
- Un signal nul (micro refusé par macOS) est détecté et expliqué.

### Carte de résultat
Elle affiche dans l'ordre :

1. la **source** : `SOURCE  FICHIER · query_001.wav` (cyan) ou
   `SOURCE  MICROPHONE · 5 s` (ambre) ;
2. le statut : *Morceau reconnu*, *Morceau non reconnu*,
   *Décision indéterminée* ;
3. le **titre** (en grand), puis `Artiste : … · Genre : …` ;
4. une phrase explicative ;
5. les champs : identifiant (`#19 · FMA 213`), fichier de référence, S1, S2,
   seuil, position dans la référence (morceau reconnu uniquement) et temps de
   traitement (appel à `recognize_query` seul).

Pour un morceau inconnu : « Absent de la bibliothèque ou insuffisamment
reconnu », avec S1 et le seuil, sans identifiant ni position. Aucun score
n'est présenté comme une probabilité.

### Zone d'analyse (onglets)
Chaque onglet graphique comporte une légende au-dessus des axes (source,
paramètres, valeurs clés). Les titres des axes restent courts et ne sont
plus tronqués.

1. **Signal** : signal d'entrée en mono, avant prétraitement.
2. **Spectrogramme** : `diag.S_dB` sur 80 dB, avec la constellation
   superposable.
3. **Constellation** : `diag.peaks` et les bandes de `cfg.peaks`.
4. **Alignement** : votes par décalage Δ pour le meilleur candidat, seuil,
   cinq meilleurs candidats. La légende donne le pic, Δ et S2. Pour un rejet,
   le pic n'est pas présenté comme une position.
5. **Système** : index, références, Fs, seuil, paramètres, état des
   métadonnées et anomalies détectées.
6. **Historique** : heure, source (`Fichier · …` / `Microphone · …`),
   résultat, morceau (`#19 Boute — Au`), S1, S2, temps. Les largeurs de
   colonnes sont recalculées à chaque redimensionnement.

### Adaptation à la fenêtre
- La taille initiale s'adapte à l'écran (au plus 1400 × 880).
- La colonne de gauche mesure 360 ou 390 px selon la largeur. La carte
  résultat occupe la hauteur restante, avec un minimum garanti : la colonne
  défile verticalement si la fenêtre est trop basse.
- Les onglets se partagent la largeur disponible ; l'en-tête se resserre
  sur les petits écrans.

---

## 4. Procédure de tests

### 4.1 Tests automatisés

```matlab
cd ~/Projects/music-fingerprinting-matlab
run('gui/test_AudioID.m')
```

Le script affiche un bilan OK / ÉCHEC / NON EXÉCUTÉ par scénario. Il ne
modifie aucun fichier du dépôt : les fichiers temporaires sont écrits dans
`tempdir`.

| # | Scénario | Vérification |
|---|---|---|
| 1 | Chargement de l'index | `IsLoaded`, `LoadCount == 1`, index non vide, **seuil = 22** |
| 2 | Fichier connu | `is_known`, bon `song_id`, écart de décalage ≤ 0,1 s |
| 3 | Fichier inconnu | `is_known == false`, `song_id == 0`, ni identifiant ni position affichés |
| 5 | Spectrogramme et pics | image = `diag.S_dB`, un marqueur par pic |
| 6 | Histogramme | pic = S1, candidats corrects, pic non masqué par l'axe |
| 7 | Index absent | interface ouverte, reconnaissance refusée (`AudioID:notLoaded`) |
| 9 | Fichier invalide | fichier corrompu → `AudioID:invalidFile` ; 0,3 s → `AudioID:tooShort` |
| 10 | Répétitions | 6 reconnaissances, `LoadCount` reste égal à 1 |
| 11 | Métadonnées | statut `ok`, 100/100, table alignée sur `song_id`, `fma_id` = fichiers indexés |
| 12 | Morceau n°19 | `audio_files{19}` = `000213.mp3` ; affichage « Boute », « Au », « Pop », `#19 · FMA 213` |
| 13 | Métadonnées incompatibles | `fma_id` échangés → 98/100 ; sans `song_id` → rejet et « Titre non disponible » ; fichier absent ; restauration sans recharger l'index |
| 14 | Scores inchangés | résultats identiques avec et sans métadonnées ; 120 requêtes identiques à `results/evaluation_scores.csv` (S1, S2, ID prédit) |

### 4.2 Tests manuels après modification

| # | Procédure | Résultat attendu |
|---|---|---|
| M1 | Ouvrir AudioID | Pastille « Bibliothèque prête » ; Système → Métadonnées « 100/100 morceaux vérifiés » |
| M2 | Fichier : `data/queries/evaluation/query_001.wav` → **Identifier** | Source FICHIER ; « Boute », Artiste : Au · Genre : Pop ; `#19 · FMA 213` |
| M3 | Micro 5 s, morceau connu diffusé à environ 30 cm | Source MICROPHONE pendant et après l'écoute ; titre, artiste et genre corrects |
| M4 | Relancer immédiatement **deux autres** enregistrements (3 s puis 10 s) | Chaque acquisition démarre, le bouton revient à « Écouter et identifier » et le message indique « Prêt pour un nouvel enregistrement » |
| M5 | Pendant un enregistrement, cliquer sur **Arrêter** | « Enregistrement annulé » ; un nouvel enregistrement fonctionne ensuite |
| M6 | Après un résultat sur fichier, lancer un enregistrement | Pendant l'écoute, ni l'ancien nom de fichier ni l'ancien résultat ne restent affichés |
| M7 | Micro, morceau inconnu à deux distances | « Morceau non reconnu », S1 < 22, aucun titre |
| M8 | Onglet **Historique** après plusieurs essais | Colonnes lisibles, sources « Fichier · … » et « Microphone · … » distinctes |
| M9 | Onglet **Alignement** (reconnu, puis rejeté) | Titres, légende, seuil et barres entièrement visibles |
| M10 | Redimensionner la fenêtre (petite, puis plein écran) | Carte résultat complète (défilement si nécessaire), onglets et historique réajustés |
| M11 | **Choisir un fichier…** puis **Annuler** | « Sélection annulée » ; la sélection précédente est conservée |
| M12 | En cas de `Device Error` | Tester `r = audiorecorder(44100,16,1); recordblocking(r,1)` hors AudioID. Si l'erreur s'y reproduit, l'origine est le système audio : `sudo killall coreaudiod` |

Seuls les tests réellement exécutés doivent être déclarés réussis.

---

## 5. Architecture

```text
gui/
├── AudioID.m        Classe handle : interface, callbacks, métadonnées, tracés
├── test_AudioID.m   Tests automatisés (12 scénarios)
└── README.md        Ce document
```

- Interface programmatique (`uifigure`, `uigridlayout`, `uiaxes`), lisible et
  comparable dans Git, contrairement au format binaire `.mlapp`.
- API publique : `recognizeFile`, `recognizeSignal`, `reloadMetadata`,
  `getDisplayedResult`.
- Identifiants d'erreur : `AudioID:notLoaded`, `AudioID:invalidFile`,
  `AudioID:tooShort`, `AudioID:silent`, `AudioID:invalidSignal`,
  `AudioID:badIndex`.

---

## 6. Captures d'écran pour le rapport

1. Ouvrir AudioID et attendre « Bibliothèque prête ».
2. **Reconnaissance avec métadonnées** : `query_001.wav` → **Identifier**.
   Capturer avec **Exporter PNG** sur les onglets Spectrogramme et
   Alignement.
3. **Rejet** : une requête négative de 10 s, onglet Alignement.
4. **Microphone** : capture pendant l'écoute (`Cmd + Shift + 4`), puis après
   le résultat (**Exporter PNG**).
5. **Système** : capturer l'onglet (index, seuil, métadonnées 100/100).

**Exporter PNG** propose `report/` avec un nom horodaté. Les images restent
non suivies par Git tant qu'elles ne sont pas ajoutées.

---

## 7. Limitations connues

- Le micro dépend du pilote audio et des autorisations macOS. Une
  `Device Error` reproduite hors d'AudioID relève du système audio et non de
  l'interface.
- `diag` ne contient pas le signal prétraité : l'onglet Signal montre
  l'entrée avant prétraitement.
- Le chargement de l'index (fichier v7.3 d'environ 300 Mo) prend plusieurs
  secondes. Chaque nouvelle instance d'`AudioID` le recharge : réutiliser la
  fenêtre ouverte.
- Le défilement de la colonne de gauche nécessite la propriété
  `Scrollable` des grilles. Sur une version de MATLAB qui ne la propose pas,
  la carte résultat garde sa hauteur minimale et peut être coupée dans une
  très petite fenêtre.
- Les en-têtes de `uitable` et les boîtes de dialogue suivent le thème
  clair du système selon la version de MATLAB.
- Les performances expérimentales (TBD, TFD, accuracy) sont préliminaires et
  ne sont pas affichées.
