# Music Fingerprinting — MATLAB

## Objectif
Développer un système de reconnaissance musicale inspiré de Shazam, basé sur l'extraction d'empreintes acoustiques et leur comparaison avec une base de référence.

## Installation
1. Télécharger ou cloner ce dépôt.
2. Ouvrir MATLAB à la racine du projet.
3. Exécuter `main.m`.

## Données
- `data/references/` : morceaux de référence.
- `data/negatives/` : morceaux absents de la base.
- `data/queries/` : extraits audio à reconnaître.

Les fichiers audio ne sont pas stockés sur GitHub.

## Structure du projet
- `src/` : fonctions MATLAB.
- `tests/` : tests unitaires.
- `experiments/` : expérimentations.
- `results/` : résultats, figures et index.
- `gui/` : interface graphique.
- `report/` : rapport.
- `presentation/` : supports de présentation.

## Contrats d'interface
À définir collectivement avant l'intégration des modules.

## Décisions d'équipe
Les paramètres communs sont centralisés dans `config.m`.
