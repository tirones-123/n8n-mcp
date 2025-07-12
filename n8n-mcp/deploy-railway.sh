#!/bin/bash
# Script pour déployer n8n-mcp sur Railway directement

echo "🚀 Déploiement n8n-mcp sur Railway avec support SSE"

# Vérifier que Railway CLI est installé
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI n'est pas installé"
    echo "Installez-le avec: npm install -g @railway/cli"
    exit 1
fi

# Login Railway si nécessaire
railway login

# Créer/lier le projet
echo "📦 Création du projet Railway..."
railway init

# Définir les variables d'environnement
echo "🔧 Configuration des variables d'environnement..."
railway variables set MCP_MODE=http
railway variables set USE_SSE=true
railway variables set AUTH_TOKEN="$AUTH_TOKEN"
railway variables set PORT=3000
railway variables set NODE_ENV=production
railway variables set LOG_LEVEL=info
railway variables set N8N_API_URL="$N8N_API_URL"
railway variables set N8N_API_KEY="$N8N_API_KEY"

# Déployer
echo "🚂 Déploiement en cours..."
railway up

echo "✅ Déploiement terminé !"
echo "URL: $(railway domain)" 