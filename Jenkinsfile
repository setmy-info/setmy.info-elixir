pipeline {

    // version 1.1.0 - hotfix* branch support (Publish/Hotfix candidate stage, HOTFIX_TO_* deploy
    //                 flags, jenkinsfile-starter 1.1.0), dead MASTER_TO_PRELIVE flag removed
    // version 1.0.0 - migrated from jenkinsfile-starter for setmy.info-elixir (Mix umbrella,
    // 4-app dependency demo). Maven placeholders from the starter are replaced with real Elixir
    // lifecycle commands (see requirements-rules.md / report.md in setmy.info-js for the full
    // language-agnostic spec this implements one row of, and report.md here for this repo's own
    // build history, including real precedent taken from elixir-start-project/PoC/second and
    // elixir-module-loader). No GitHub Actions workflow this time - both of those real repos
    // carry their own .github/workflows/ci.yml, but setmy.info-js's own equivalent was deleted
    // after repeated DAG-scheduling bugs; Jenkinsfile is this system's one CI definition
    // across all three languages (the ci-local/ shell emulation was removed 2026-08-25, to be
    // replaced by a shared Groovy runner that reads this file directly).

    agent any

    environment {
        PATH = "/opt/has/bin:$PATH"

        MASTER_TO_LIVE = 'DEPLOY'

        RELEASE_TO_PRELIVE = 'DEPLOY'

        DEVELOPMENT_TO_TEST = 'DEPLOY'
        RELEASE_TO_TEST = 'DEPLOY'

        DEVELOPMENT_TO_DEV = 'DEPLOY'
        RELEASE_TO_DEV = 'DEPLOY'

        // hotfix* - branched from master, one fix, quick review + the FULL
        // automated test path (nothing is skipped), merged to master, which
        // then deploys live and tags. A hotfix reaches the same
        // pre-production targets a release does and never goes live directly.
        HOTFIX_TO_PRELIVE = 'DEPLOY'
        HOTFIX_TO_TEST = 'DEPLOY'
        HOTFIX_TO_DEV = 'SKIP'
    }

    stages {
        stage('Inspection') {
            parallel {
                stage('Pre-build') {
                    steps {
                        echo 'Pre build inspection and precondition check.'
                        sh 'elixir --version'
                        script {
                            if (!fileExists('README.md')) {
                                error('README.md missing - checkout incomplete or wrong workspace directory')
                            }
                        }
                    }
                }
                stage('Build tools') {
                    steps {
                        echo 'Build tools installation and preparation (mix deps.get)'
                        sh 'mix local.hex --force'
                        sh 'mix local.rebar --force'
                        sh 'mix deps.get'
                    }
                }
            }
        }

        // Everything from here down to and including 'Package' runs on every branch, feature
        // branches included - a developer on a feature branch gets the same build/lint/test/
        // quality feedback as devel/release/master, without ever reaching Publish/Deploy/Tag.

        stage('Preparation') {
            steps {
                echo 'Preparing the workspace to be built.'
                sh 'mix clean'
                sh 'mix validate'
            }
        }

        stage('Build') {
            steps {
                echo 'Format/lint check (Maven validate phase equivalent)'
                sh 'mix format --check-formatted'
                sh 'mix credo --strict'

                echo 'Resource filtering (Maven generate-resources/process-resources phase equivalent)'
                sh 'mix resources --profile ci'

                echo 'Compile'
                sh 'mix compile --warnings-as-errors'

                echo 'Build tooling self-tests (§7.7)'
                sh 'mix tooling_test'

                echo 'Unit tests'
                sh 'mix test.unit'

                echo 'Integration tests (*IT-equivalent)'
                sh 'mix pre_integration_test'
                sh 'mix test.integration'
            }
            post {
                // Guaranteed cleanup even if integration tests fail, the same way Maven's
                // failsafe plugin always runs post-integration-test around a possibly failing
                // integration-test goal.
                always {
                    sh 'mix post_integration_test'
                }
            }
        }

        stage('E2E') {
            steps {
                echo 'e2e tests, against real running instances (§7.5)'
                sh 'mix pre_e2e_test'
                sh 'mix test.e2e'
            }
            post {
                always {
                    sh 'mix post_e2e_test'
                }
            }
        }

        stage('Quality') {
            steps {
                echo 'Put here mutation tests once wired in (neither JS nor Python side has this wired in either, though both PoCs used Muzak - see report.md)'

                echo 'Coverage, security (Sobelow + mix deps.audit), artifact verification'
                sh 'mix coverage'
                sh 'mix security'
                sh 'mix verify'

                echo 'Reporting: docs, lint report, security report, dependency tree (mvn site equivalent)'
                sh 'mix sbom'
                sh 'mix site'
            }
        }

        stage('System/Acceptance') {
            steps {
                echo 'Put here system tests'
                echo 'Put here acceptance tests'
            }
        }

        stage('Package') {
            steps {
                echo 'Packaging (Hex tarball via mix hex.build)'
                sh 'mix package'
                sh 'mix sign'
            }
        }

        stage('Publish') {
            parallel {
                stage('Release') {
                    when {
                        branch 'master'
                    }
                    steps {
                        echo 'Software release publish steps'
                        sh 'mix install_local'
                        sh 'mix publish'
                    }
                }
                stage('Snapshot') {
                    when {
                        expression { env.BRANCH_NAME.startsWith('devel') }
                    }
                    steps {
                        echo 'Software snapshot publish steps'
                        sh 'mix install_local'
                        sh 'mix publish'
                    }
                }
                stage('Hotfix candidate') {
                    when {
                        expression { env.BRANCH_NAME.startsWith('hotfix') }
                    }
                    steps {
                        echo 'Software hotfix-candidate publish steps'
                        sh 'mix install_local'
                        sh 'mix publish'
                    }
                }
                stage('Release reports') {
                    when {
                        branch 'master'
                    }
                    steps {
                        echo 'Put here reports publishing steps (deploy docs/ output)'
                    }
                }
                stage('Snapshot reports') {
                    when {
                        expression { env.BRANCH_NAME.startsWith('devel') }
                    }
                    steps {
                        echo 'Put here reports publishing steps (deploy docs/ output)'
                    }
                }
            }
        }

        stage('Deploy') {
            parallel {
                stage('dev') {
                    when {
                        expression {
                            (env.DEVELOPMENT_TO_DEV == 'DEPLOY' && env.BRANCH_NAME.startsWith('devel')) ||
                            (env.RELEASE_TO_DEV == 'DEPLOY' && env.BRANCH_NAME.startsWith('release')) ||
                            (env.HOTFIX_TO_DEV == 'DEPLOY' && env.BRANCH_NAME.startsWith('hotfix'))
                        }
                    }
                    steps {
                        echo 'Development environment installation steps'
                        sh 'DEPLOY_TARGET=dev mix deploy'
                    }
                }
                stage('test') {
                    when {
                        expression {
                            (env.DEVELOPMENT_TO_TEST == 'DEPLOY' && env.BRANCH_NAME.startsWith('devel')) ||
                            (env.RELEASE_TO_TEST == 'DEPLOY' && env.BRANCH_NAME.startsWith('release')) ||
                            (env.HOTFIX_TO_TEST == 'DEPLOY' && env.BRANCH_NAME.startsWith('hotfix'))
                        }
                    }
                    steps {
                        echo 'Test environment installation steps'
                        sh 'DEPLOY_TARGET=test mix deploy'
                    }
                }
                stage('prelive') {
                    when {
                        expression {
                            (env.RELEASE_TO_PRELIVE == 'DEPLOY' && env.BRANCH_NAME.startsWith('release')) ||
                            (env.HOTFIX_TO_PRELIVE == 'DEPLOY' && env.BRANCH_NAME.startsWith('hotfix'))
                        }
                    }
                    steps {
                        echo 'Prelive environment installation steps'
                        sh 'DEPLOY_TARGET=prelive mix deploy'
                    }
                }
                stage('live') {
                    when {
                        expression {
                            env.MASTER_TO_LIVE == 'DEPLOY' && env.BRANCH_NAME == 'master'
                        }
                    }
                    steps {
                        echo 'Production environment installation steps'
                        sh 'DEPLOY_TARGET=live mix deploy'
                    }
                }
            }
        }

        stage('Tag') {
            when {
                branch 'master'
                expression { env.MASTER_TO_LIVE == 'DEPLOY' }
            }
            steps {
                echo 'Put here tagging steps'
            }
        }
    }

    post {
        always {
            sh 'echo "Always"'
        }

        success {
            emailext (
                subject: "Jenkins job: $JOB_NAME, build: $BUILD_NUMBER type: SUCCESSFUL",
                body: "Job: $JOB_NAME, build: $BUILD_NUMBER, url: ${env.BUILD_URL}, git: ${env.GIT_URL}, branch: ${env.GIT_BRANCH} SUCCESSFUL post step",
                recipientProviders: [[$class: 'DevelopersRecipientProvider']]
            )
        }

        failure {
            emailext (
                subject: "Jenkins job: $JOB_NAME, build: $BUILD_NUMBER type: FAILED",
                body: "Job: $JOB_NAME, build: $BUILD_NUMBER, url: ${env.BUILD_URL}, git: ${env.GIT_URL}, branch: ${env.GIT_BRANCH}  FAILED post step",
                recipientProviders: [[$class: 'DevelopersRecipientProvider']]
            )
        }
    }
}
