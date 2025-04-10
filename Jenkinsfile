pipeline {
    agent any
    environment {
        CONSUL_URL = 'https://consul-ui-dev.pntrzz.com/v1/kv'
        CONSUL_TOKEN = credentials('CONSUL_HTTP_TOKEN_LAST_MILE')
    }

    stages {
        stage('Checkout Code') {
            steps { checkout scm }
        }
        stage('Sync Config to Consul') {
            when { changeset "**/config/config.json" }
            steps {
                script {
                    def results = [
                        created: [],
                        updated: [],
                        deleted: [],
                        failed: []
                    ]

                    // Process each changed config file
                    def changedFiles = sh(script: 'git diff --name-only HEAD~1 HEAD -- "**/config/config.json"', returnStdout: true)
                        .trim().split('\n')

                    changedFiles.each { configFile ->
                        try {
                            def app = configFile.split('/')[0]
                            def config = readJSON file: configFile

                            if (!config.ENV) error "❌ Missing ENV in ${configFile}"
                            def consulPrefix = "${app}/${config.ENV}"

                            // 1. Get current Consul keys for this app/env (without the full prefix)
                            def currentKeysRelative = []
                            try {
                                def response = sh(script: """
                                    curl -sS -H "X-Consul-Token: $CONSUL_TOKEN" \
                                    "$CONSUL_URL/${consulPrefix}/?keys"
                                """, returnStdout: true)
                                currentKeysRelative = response ? readJSON(text: response).collect { it.substring("${consulPrefix}/".length()) } : []
                            } catch(e) { echo "⚠️ No existing keys found for ${consulPrefix}" }

                            // 2. Process all keys from config file
                            def configKeysRelative = []
                            config.each { key, value ->
                                if (key == 'ENV') return
                                configKeysRelative << key
                                def consulKey = "${consulPrefix}/${key}"
                                def newValue = value?.toString()?.trim() ?: ""

                                // Check current value
                                def currentValue = ""
                                try {
                                    currentValue = sh(script: """
                                        curl -sS -H "X-Consul-Token: $CONSUL_TOKEN" \
                                        "$CONSUL_URL/${consulKey}?raw=true"
                                    """, returnStdout: true).trim()
                                } catch(e) { echo "⚠️ Key ${consulKey} not found in Consul" }

                                // Update if changed
                                if (currentValue != newValue) {
                                    try {
                                        sh """
                                            curl -X PUT -sS -H "X-Consul-Token: $CONSUL_TOKEN" \
                                            -d '$newValue' "$CONSUL_URL/${consulKey}"
                                        """
                                        results[currentValue ? 'updated' : 'created'] << consulKey
                                        echo "${currentValue ? '🔄 Updated' : '➕ Created'} ${consulKey}"
                                    } catch(e) {
                                        results.failed << consulKey
                                        echo "❌ Failed to update ${consulKey}"
                                    }
                                }
                            }

                            // 3. Delete keys not in config but exist in Consul
                            currentKeysRelative.findAll { !configKeysRelative.contains(it) }
                                .each { relativeKeyToDelete ->
                                    def fullKeyToDelete = "${consulPrefix}/${relativeKeyToDelete}"
                                    try {
                                        sh """
                                            curl -X DELETE -sS -H "X-Consul-Token: $CONSUL_TOKEN" \
                                            "$CONSUL_URL/${fullKeyToDelete}"
                                        """
                                        results.deleted << fullKeyToDelete
                                        echo "🗑️ Deleted ${fullKeyToDelete}"
                                    } catch(e) {
                                        results.failed << fullKeyToDelete
                                        echo "❌ Failed to delete ${fullKeyToDelete}"
                                    }
                                }

                        } catch(e) {
                            results.failed << configFile
                            echo "❌ Failed to process ${configFile}: ${e.message}"
                        }
                    }

                    // Generate summary report
                    def summary = """
                    ============= CONSUL SYNC REPORT =============
                    📝 Processed ${changedFiles.size()} config file(s)
                    🆕 Created: ${results.created.size()}
                    ✏️ Updated: ${results.updated.size()}
                    🗑️ Deleted: ${results.deleted.size()}
                    ❌ Failed: ${results.failed.size()}
                    ==============================================
                    """
                    echo summary

                    if (results.failed) error "Completed with errors"
                }
            }
        }
    }

    post {
        success { echo "✅ Consul sync completed successfully" }
        failure { echo "❌ Consul sync failed" }
    }
}