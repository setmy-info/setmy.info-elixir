def runCommand(String command) {
    if (isUnix()) {
        sh command
    } else {
        bat command
    }
}

// Publishing needs a Hex API key; without one `mix hex.publish` blocks on an interactive
// authentication prompt, so the stage says what it skipped instead of hanging the build.
void publishPackages() {
    script {
        if (env.HEX_API_KEY) {
            withEnv(['HEX_BUILD=1']) {
                runCommand 'mix cmd mix hex.publish --yes'
            }
        } else {
            echo 'HEX_API_KEY is not set - skipping mix hex.publish. The Package stage already built every tarball.'
        }
    }
}

pipeline {

    // version 2.0.0 - the Maven-lifecycle emulation was removed. Stages now run plain Mix
    //                 commands (compile, test.unit/test.integration/test.e2e, format, credo,
    //                 dialyzer, sobelow, deps.audit, coveralls, docs, hex.build/hex.publish,
    //                 release) instead of the custom validate/resources/verify/package/sign/
    //                 sbom/install_local/publish/deploy tasks that used to live in a dev_tasks
    //                 app. Servers are no longer started and stopped around the test tiers -
    //                 each app supervises its own HTTP endpoint.
    // version 1.2.0 - migrated from jenkinsfile-starter's current Jenkinsfile (commit ad074a6):
    //                 pollSCM trigger, options { buildDiscarder + quietPeriod +
    //                 disableConcurrentBuilds(abortPrevious: true) }, declarative `when`
    //                 branch/environment conditions with comparator: 'REGEXP' instead of
    //                 expression { env.BRANCH_NAME.startsWith(...) }, cross-platform
    //                 runCommand() helper
    // version 1.1.0 - hotfix* branch support (Publish/Hotfix candidate stage, HOTFIX_TO_* deploy
    //                 flags, jenkinsfile-starter 1.1.0), dead MASTER_TO_PRELIVE flag removed
    // version 1.0.0 - migrated from jenkinsfile-starter for setmy.info-elixir (Mix umbrella,
    //                 4-app dependency demo). No GitHub Actions workflow: this Jenkinsfile is
    //                 the one CI definition for the repo.

    /*
    Git branches flow: develop -> feature -> develop -> release -> master

    Building only the newest change
    Every branch is polled for new commits, and commits arrive in bursts. Building each one of
    them is wasted work, so a burst is collapsed twice: quietPeriod folds the commits that have
    not started building yet into a single build, and disableConcurrentBuilds(abortPrevious:
    true) aborts a run that is already in progress as soon as a newer one is ready. What gets
    built is the newest change; the intermediate ones are skipped, not queued. See the options
    block.

    Steps
    1. Enhancement event
    2. feature branch from develop
    3. Enhancements in feature branch - built on new commits, only the newest change is built
    4. After successful build merge to develop - built on new commits, only the newest change is built
    5. Go-No go event: Positive release and release testing decision by DEV and TEST environments
    6. Make release branch - built on new commits, only the newest change is built. Code freeze period started.
    7. Go-No go event: Positive release decision by DEV, TEST, PRELIVE environments
    8. Merge release branch to master - built on new commits, only the newest change is built. Code freeze period ended.
    9. Found a bug in production
    10. hotfix branch from master
    11. Enhancements in hotfix branch - built on new commits, only the newest change is built
    12. Go-No go event: the hotfix is deployed to TEST and PRELIVE, where QA validates and
        verifies it. The decision taken there is either "this is verified" - go to step 15 - or
        "this needs more testing" - go to step 13.
    13. Hotfix merged to develop, when the decision at step 12 asked for more testing.
    14. The development flow continues from step 4, so the fix now also reaches DEV and is
        tested again together with everything else on develop.
    15. Hotfix merged to master. master is what deploys live and tags.

    Automatic deployments to environments: every deployment below is triggered by the build
    itself and gated only by the *_TO_* flags in the environment block. There is no manual
    approval step (no input step) anywhere in this pipeline.

    hotfix* - branched from master, one fix, quick review, then TEST and PRELIVE, where
    QA validates and verifies it. It deliberately does not deploy to DEV: DEV is the
    development integration target and a hotfix integrates nothing. If QA decides the fix
    needs more testing it is merged to develop, and it reaches DEV through the normal
    development flow from there. A hotfix is merged to master to go live, and master is
    what deploys live and tags - a hotfix never goes live directly.

    No pull request builds.

    [5 branches] x [4 environments]. feature* deploys nowhere: it is built and tested only.
    */

    agent any

    triggers {
        // pollSCM, not cron: cron fires on the timer whether or not anything was pushed, so it
        // builds the same commit over and over. pollSCM asks the SCM every 5 minutes and only
        // triggers when there really are new commits. H spreads the poll across the interval so
        // that all jobs do not hit the SCM in the same second.
        //
        // In a MULTIBRANCH pipeline this is redundant and costs more than it gives: the folder
        // already discovers commits by branch indexing, and this makes every branch job poll the
        // repository separately on top of that - N branches, N pollers, all against one remote.
        // The multibranch way is to leave this out and drive builds from either a webhook (best:
        // instant, no polling at all) or the folder's own "Scan Multibranch Pipeline Triggers".
        // It is kept here because this Jenkinsfile is also meant to work as a single branch job,
        // where nothing else would trigger it.
        pollSCM('H/5 * * * *')
    }

    options {
        buildDiscarder(
            logRotator(
                numToKeepStr: '20',
                artifactNumToKeepStr: '10'
            )
        )

        // Commits arrive in bursts, and building every intermediate commit is wasted work.
        // Two different mechanisms are needed, because they solve two different halves:
        //
        // quietPeriod - the burst that has not started building yet. After a trigger Jenkins
        // holds the queue item this long before it becomes buildable, and every further commit
        // inside the window folds into the same build.
        //
        // Both of these are PER JOB, and in a multibranch pipeline every branch is its own job.
        // A quiet period on one branch does not hold another branch back - their windows count
        // down at the same time - but it does delay every branch by this much, which is very
        // visible when several branches are pushed at once. Keep it short: it only has to cover
        // how long a push burst takes, not how long a build takes. Set it to 0 while testing the
        // pipeline itself.
        //
        // disableConcurrentBuilds(abortPrevious: true) - the build that is already running.
        // Without it Jenkins starts a second run beside the first whenever an executor is
        // free, so several intermediate commits build at once. With it the runs of THIS branch
        // are serialised, and abortPrevious kills the older run the moment a newer one is ready:
        // the newest change wins and the superseded ones never finish. Other branches are not
        // affected - if branches are waiting for each other, that is the executor count, not
        // this option.
        quietPeriod(15)
        disableConcurrentBuilds(abortPrevious: true)
    }

    environment {
        PATH = "/opt/has/bin:$PATH"

        MASTER_TO_LIVE = 'DEPLOY'

        RELEASE_TO_PRELIVE = 'DEPLOY'
        HOTFIX_TO_PRELIVE = 'DEPLOY'

        // "TEST", not "TESTING" - ADR-0041's canonical environment name.
        DEVELOPMENT_TO_TEST = 'DEPLOY'
        RELEASE_TO_TEST = 'DEPLOY'
        HOTFIX_TO_TEST = 'DEPLOY'

        DEVELOPMENT_TO_DEV = 'DEPLOY'
        RELEASE_TO_DEV = 'DEPLOY'
        // hotfix* deliberately does not reach DEV: DEV is the development integration target
        // and a hotfix integrates nothing. The flag exists so the exception is visible rather
        // than implied by a missing condition.
        HOTFIX_TO_DEV = 'SKIP'
    }

    stages {
        stage('Inspection') {
            parallel {
                stage('Pre-build') {
                    steps {
                        echo "Jenkins node: ${env.NODE_NAME}"
                        echo "Operating system: ${isUnix() ? 'Unix/Linux' : 'Windows'}"

                        echo 'Pre build inspection and precondition check.'
                        runCommand 'elixir --version'
                        // fileExists only RETURNS a boolean - as a bare
                        // statement its result is discarded and a missing
                        // file fails nothing. It must be wrapped to gate.
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
                        runCommand 'mix local.hex --force'
                        runCommand 'mix local.rebar --force'
                        runCommand 'mix deps.get'
                    }
                }
            }
        }

        // Everything from here down to and including 'Package' runs on every branch, feature
        // branches included - a developer on a feature branch gets the same build/lint/test/
        // quality feedback as devel/release/master, without ever reaching Publish/Deploy/Tag.

        stage('Build') {
            steps {
                echo 'Compile the whole umbrella, warnings are errors.'
                runCommand 'mix clean'
                runCommand 'mix compile --warnings-as-errors'
            }
        }

        // The three test tiers run one by one, as separate stages, so a failure names the
        // tier it happened in. Each app's own supervision tree brings up its HTTP endpoint,
        // so the integration and e2e tiers need no server started or stopped around them.
        stage('Unit tests') {
            steps {
                runCommand 'mix test.unit'
            }
        }

        stage('Integration tests') {
            steps {
                runCommand 'mix test.integration'
            }
        }

        stage('E2E tests') {
            steps {
                runCommand 'mix test.e2e'
            }
        }

        stage('Quality') {
            parallel {
                stage('Format and lint') {
                    steps {
                        runCommand 'mix format --check-formatted'
                        runCommand 'mix credo --strict'
                    }
                }
                stage('Types') {
                    steps {
                        runCommand 'mix dialyzer'
                    }
                }
                stage('Security') {
                    steps {
                        // Static analysis per app, then the dependency advisory audit.
                        runCommand 'mix sobelow'
                        runCommand 'mix audit'
                    }
                }
            }
        }

        stage('Coverage and docs') {
            steps {
                echo 'Aggregate coverage over all three tiers, plus the API documentation.'
                runCommand 'mix coverage'
                runCommand 'mix docs'
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
                echo 'One Hex tarball per app - each app is published separately.'
                // HEX_BUILD switches the in_umbrella sibling deps to their published Hex
                // names; see apps/demo_module_c/mix.exs for why it is not always on.
                withEnv(['HEX_BUILD=1']) {
                    runCommand 'mix cmd mix hex.build'
                }
            }
        }

        // comparator: 'REGEXP' below is not decoration. The default GLOB comparator's `*` does
        // not cross a `/`, so `branch 'release*'` does NOT match `release/1.2.0` and `branch
        // 'hotfix*'` does NOT match `hotfix/NPE` - every publish and deployment for those two
        // branches is then silently skipped. It is easy to miss, because `devel*` keeps working:
        // `develop` has no separator in it. 'release.*' as a regular expression is what the
        // earlier expression { env.BRANCH_NAME.startsWith('release') } actually meant. Use
        // branch 'release/*' instead only if every release branch really is named with a slash.
        stage('Publish') {
            parallel {
                stage('Release') {
                    when {
                        branch 'master'
                    }
                    steps {
                        echo 'Software release publish steps'
                        publishPackages()
                    }
                }
                stage('Snapshot') {
                    when {
                        branch pattern: 'devel.*', comparator: 'REGEXP'
                    }
                    steps {
                        echo 'Software snapshot publish steps'
                        publishPackages()
                    }
                }
                stage('Hotfix candidate') {
                    when {
                        branch pattern: 'hotfix.*', comparator: 'REGEXP'
                    }
                    steps {
                        echo 'Software hotfix-candidate publish steps'
                        publishPackages()
                    }
                }
                stage('Release reports') {
                    when {
                        branch 'master'
                    }
                    steps {
                        echo 'Put here reports publishing steps (deploy doc/ and cover/ output)'
                    }
                }
                stage('Snapshot reports') {
                    when {
                        branch pattern: 'devel.*', comparator: 'REGEXP'
                    }
                    steps {
                        echo 'Put here reports publishing steps (deploy doc/ and cover/ output)'
                    }
                }
            }
        }

        stage('Deploy') {
            parallel {
                stage('dev') {
                    when {
                        anyOf {
                            allOf {
                                environment name: 'DEVELOPMENT_TO_DEV', value: 'DEPLOY'
                                branch pattern: 'devel.*', comparator: 'REGEXP'
                            }
                            allOf {
                                environment name: 'RELEASE_TO_DEV', value: 'DEPLOY'
                                branch pattern: 'release.*', comparator: 'REGEXP'
                            }
                            allOf {
                                environment name: 'HOTFIX_TO_DEV', value: 'DEPLOY'
                                branch pattern: 'hotfix.*', comparator: 'REGEXP'
                            }
                        }
                    }
                    steps {
                        echo 'Development environment installation steps'
                        // One OTP release per app, built for this environment. Installing
                        // them on a real host is not wired up yet.
                        //
                        // withEnv, not a `VAR=value command` shell prefix: that prefix is
                        // Bourne-shell syntax and does nothing under bat on a Windows agent.
                        withEnv(['MIX_ENV=dev']) {
                            runCommand 'mix release.all --overwrite'
                        }
                    }
                }
                stage('test') {
                    when {
                        anyOf {
                            allOf {
                                environment name: 'DEVELOPMENT_TO_TEST', value: 'DEPLOY'
                                branch pattern: 'devel.*', comparator: 'REGEXP'
                            }
                            allOf {
                                environment name: 'RELEASE_TO_TEST', value: 'DEPLOY'
                                branch pattern: 'release.*', comparator: 'REGEXP'
                            }
                            allOf {
                                environment name: 'HOTFIX_TO_TEST', value: 'DEPLOY'
                                branch pattern: 'hotfix.*', comparator: 'REGEXP'
                            }
                        }
                    }
                    steps {
                        echo 'Test environment installation steps'
                        // One OTP release per app, built for this environment. Installing
                        // them on a real host is not wired up yet.
                        withEnv(['MIX_ENV=test']) {
                            runCommand 'mix release.all --overwrite'
                        }
                    }
                }
                stage('prelive') {
                    when {
                        anyOf {
                            allOf {
                                environment name: 'RELEASE_TO_PRELIVE', value: 'DEPLOY'
                                branch pattern: 'release.*', comparator: 'REGEXP'
                            }
                            allOf {
                                environment name: 'HOTFIX_TO_PRELIVE', value: 'DEPLOY'
                                branch pattern: 'hotfix.*', comparator: 'REGEXP'
                            }
                        }
                    }
                    steps {
                        echo 'Prelive environment installation steps'
                        // One OTP release per app, built for this environment. Installing
                        // them on a real host is not wired up yet.
                        withEnv(['MIX_ENV=prelive']) {
                            runCommand 'mix release.all --overwrite'
                        }
                    }
                }
                stage('live') {
                    when {
                        environment name: 'MASTER_TO_LIVE', value: 'DEPLOY'
                        branch 'master'
                    }
                    steps {
                        echo 'Production environment installation steps'
                        // One OTP release per app, built for this environment. Installing
                        // them on a real host is not wired up yet.
                        withEnv(['MIX_ENV=live']) {
                            runCommand 'mix release.all --overwrite'
                        }
                    }
                }
            }
        }

        stage('Tag') {
            when {
                environment name: 'MASTER_TO_LIVE', value: 'DEPLOY'
                branch 'master'
            }
            steps {
                echo 'Put here tagging steps'
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'cover/**, doc/**, apps/*/*.tar', allowEmptyArchive: true, fingerprint: true
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
