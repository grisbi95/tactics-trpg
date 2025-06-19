# TRPG Tactics - Projet Godot 4.4

## 🎮 Description
Un jeu de stratégie tactique (TRPG) développé avec Godot 4.4, conçu pour être simple, clair et bien organisé.

## 📁 Structure du Projet
Le projet suit une architecture modulaire organisée selon les bonnes pratiques définies dans `cursorrules.mdc` :

```
tactics/
├── cursorrules.mdc     # Règles de développement du projet
├── scenes/             # Scènes Godot (.tscn)
├── scripts/            # Scripts GDScript (.gd)
├── resources/          # Ressources réutilisables (.tres, .res)
├── assets/             # Assets média (sprites, audio, fonts)
└── addons/             # Plugins Godot
```

## 🚀 Premiers Pas

### 1. Règles de Développement
**Important** : Avant de commencer à coder, lisez attentivement le fichier `cursorrules.mdc` qui contient toutes les conventions et bonnes pratiques à suivre.

### 2. Scripts d'Exemple
Le fichier `scripts/core/game_manager.gd` montre un exemple de structure de script respectant les règles établies.

### 3. Conventions de Nommage
- **Classes** : PascalCase (`BattleManager`)
- **Variables** : snake_case (`current_health`)
- **Constantes** : SCREAMING_SNAKE_CASE (`MAX_LEVEL`)
- **Fonctions** : snake_case (`calculate_damage()`)

## 🎯 Philosophie de Développement

### Simplicité d'Abord
Ce projet privilégie :
- ✅ **Clarté** plutôt que performance
- ✅ **Fonctionnalité** plutôt que perfection
- ✅ **Itération rapide** avec des fonctionnalités testables
- ✅ **Documentation minimale** mais utile

### Architecture KISS
- Maximum 3 niveaux d'héritage
- Une responsabilité par classe
- Éviter l'over-engineering
- Préférer la composition à l'héritage

## 📋 Checklist Avant Commit
- [ ] Code suit les conventions de `cursorrules.mdc`
- [ ] Pas de `print()` oublié (utiliser `print_debug()`)
- [ ] Variables exportées avec valeurs par défaut
- [ ] Signaux documentés
- [ ] Pas de warnings dans l'éditeur

## 🔧 Développement

### Messages de Commit
- `feat:` nouvelles fonctionnalités
- `fix:` corrections de bugs
- `refactor:` refactoring de code
- `ui:` modifications d'interface
- `assets:` ajout/modification d'assets

### Mode Debug
Utiliser les variables `debug_mode` exportées pour activer les logs de développement.

## 🤝 Contribution
Ce projet suit une approche hobbyiste privilégiant la simplicité et la clarté. Consultez `cursorrules.mdc` pour connaître toutes les règles de contribution.

---
*Développé avec ❤️ et Godot 4.4* 