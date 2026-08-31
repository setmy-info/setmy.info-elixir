
def runCommand(String command) {
    if (isUnix()) {
        sh command
    } else {
        bat command
    }
}

pipeline {

    /*
    version 1.2.0 - release* no longer deploys to DEV: the RELEASE_TO_DEV flag and the release
                    branch of the 'dev' deploy stage are gone. release* deploys to TEST and
                    PRELIVE only. develop -> DEV is unchanged.
    version 1.1.0 - pollSCM instead of cron (build on new commits, not on a timer),
                    quietPeriod + disableConcurrentBuilds(abortPrevious: true) so that a burst
                    of commits becomes one build of the newest change,
                    elease* added to Publish/Snapshot: develop, release* and hotfix* all publish
                    a candidate of unknown quality
                    TEST environment renamed to the ADR-0041 canonical name
    version 1.0.1 - fileExists precondition check now actually gates (was a discarded boolean)

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
        // The 4-space `mix format` plugin (apps/formatter) falls back to stock 2-space output
        // with a warning when widening would change a file's AST. That fallback is
        // deterministic, so `--check-formatted` would compare it against itself and PASS -
        // the gate could not enforce the rule it exists for. Strict turns the fallback into an
        // error, so no file reaches master at 2 spaces.
        FOUR_SPACES_STRICT = '1'

        SMI_PROFILES = 'ci'

        MASTER_TO_LIVE = 'DEPLOY'

        RELEASE_TO_PRELIVE = 'DEPLOY'
        HOTFIX_TO_PRELIVE = 'DEPLOY'

        DEVELOPMENT_TO_TEST = 'DEPLOY'
        RELEASE_TO_TEST = 'DEPLOY'
        HOTFIX_TO_TEST = 'DEPLOY'

        DEVELOPMENT_TO_DEV = 'DEPLOY'
    }

    stages {
        stage('Inspection') {
            parallel {
                stage('Pre-build') {
                    /*
                    Pre build existing environment conditions, versions, CI build info into the log.
                    */
                    steps {
                        echo "Jenkins node: ${env.NODE_NAME}"
                        echo "Operating system: ${isUnix() ? 'Unix/Linux' : 'Windows'}"

                        echo 'Pre build inspection and precondition check.'
                        runCommand 'elixir --version'
                        runCommand 'mix --version'
                    }
                }
                /*
                Stage to install build required tools. Build dependencies.
                */
                stage('Build tools') {
                    steps {
                        echo 'Build tools installation and preparation (setup, config)'
                        runCommand 'mix local.hex --force'
                        runCommand 'mix local.rebar --force'
                    }
                }
            }
        }

        stage('Preparation') {
            parallel {
                /*
                Stage to install language and source, language code dependencies.
                */
                stage('Install') {
                    steps {
                        echo 'Preparing the software to be built. Installation commands go here.'
                        runCommand 'mix deps.get'
                        echo 'Put here build configuration commands'
                        runCommand 'mix deps.unlock --check-unused'
                    }
                }
            }
        }

        /*
        Stage to build code with executing all needed steps to measure different type of code quality.
        Each command is its own line, so the build log names exactly what failed.
        */
        stage('Build') {
            steps {
                echo 'Cleaning command, because in some cases shared directories can have previous build garbage'
                runCommand 'mix clean'

                echo 'Put here resource copy commands'
                echo 'Nothing to copy: each app serves its own priv/web straight out of the app.'

                echo 'Put here compilation commands. Can be omitted.'
                runCommand 'mix compile --warnings-as-errors'
                runCommand 'mix test.compile'

                echo 'Put here unit tests'
                runCommand 'mix test.unit'

                echo 'Put here integration tests. Previous steps can be merged here.'
                // Self-bracketing: mix.exs runs pre-integration-test before and
                // post-integration-test after, and the post phase also on failure.
                runCommand 'mix test.integration'

                echo 'Put here mutation tests'
                echo 'No mutation testing tool for Elixir in the org toolchain yet.'

                echo 'Put here reporting builds steps can include (unit tests coverage, mutation test coverage, findbugs, vuln. checks, )'
                echo 'Containing here findbug/stopbug, check style, dependencies vulnreability checks, docs gen, etc'
                // Gates first (each fails the build on a finding), documents second.
                runCommand 'mix format --check-formatted'
                runCommand 'mix quality'
                runCommand 'mix reports'

                echo 'Put here site deploy'
                echo 'No site deploy: doc/, cover/ and reports/ are archived below instead.'

                echo 'Put here e2e tests'
                runCommand 'mix test.e2e'

                echo 'Put here system tests'
                echo 'Put here acceptance tests'
                echo 'System and acceptance testing are the e2e tier here - the tiers run against the release daemons.'

                echo 'Put here packaging'
                runCommand 'mix package'

                echo 'Put here local publishing'
                echo 'Nothing local to publish: Hex is the registry, see the Publish stage.'
            }
        }

        stage('Publish') {
            parallel {
                /*
                Stage to push or upload build packages/artifacts to file storage systems.
                */
                stage('Release') {
                    when {
                        branch 'master'
                        // Without a key `mix hex.publish` blocks on an interactive
                        // authentication prompt, which would hang the build.
                        expression { env.HEX_API_KEY }
                    }
                    steps {
                        echo 'Put here software release steps'
                        // `hex.publish package`, not bare `hex.publish`: the bare form also
                        // builds docs, and ex_doc is an umbrella-root dependency that an app
                        // directory cannot see.
                        runCommand 'mix package.publish'
                    }
                }
                stage('Snapshot') {
                    when {
                        branch pattern: 'devel.*', comparator: 'REGEXP'
                    }
                    steps {
                        echo 'Put here software snapshot publishing steps'
                        // Hex has no snapshots - a version publishes exactly once - so a
                        // development build keeps its tarballs as archived artifacts instead.
                        echo 'Hex has no snapshots: the tarballs built above are archived by post/always.'
                    }
                }
                stage('Release reports') {
                    when {
                        branch 'master'
                    }
                    steps {
                        echo 'Put here reports publishing steps'
                        echo 'doc/, cover/ and reports/ are archived by post/always.'
                    }
                }
                stage('Snapshot reports') {
                    when {
                        branch pattern: 'devel.*', comparator: 'REGEXP'
                    }
                    steps {
                        echo 'Put here reports publishing steps'
                        echo 'doc/, cover/ and reports/ are archived by post/always.'
                    }
                }
            }
        }
        stage('Deploy') {
            parallel {
                /*
                Stages to deploy/install artifacts to different environments.
                One OTP release per deployable app; `mix release.all` builds them all.
                */
                stage('dev') {
                    when {
                        environment name: 'DEVELOPMENT_TO_DEV', value: 'DEPLOY'
                        branch pattern: 'devel.*', comparator: 'REGEXP'
                    }
                    environment {
                        MIX_ENV = 'dev'
                    }
                    steps {
                        echo 'Put here software development installations steps'
                        runCommand 'mix release.all --overwrite'
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
                    environment {
                        MIX_ENV = 'test'
                    }
                    steps {
                        echo 'Put here software test installations steps'
                        runCommand 'mix release.all --overwrite'
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
                    environment {
                        MIX_ENV = 'prelive'
                    }
                    steps {
                        echo 'Put here software prelive installations steps'
                        runCommand 'mix release.all --overwrite'
                    }
                }
                stage('live') {
                    when {
                        environment name: 'MASTER_TO_LIVE', value: 'DEPLOY'
                        branch 'master'
                    }
                    environment {
                        MIX_ENV = 'live'
                    }
                    steps {
                        echo 'Put here software production installations steps'
                        runCommand 'mix release.all --overwrite'
                    }
                }
            }
        }
        /*
        Stage to make SCM tag. As all results are succeeded then tag reflects FULL build success.
        */
        stage('Tag') {
            when {
                environment name: 'MASTER_TO_LIVE', value: 'DEPLOY'
                branch 'master'
            }
            steps {
                echo 'Put here tagging. For example: '
                echo 'smi-new-tag 1.2.3'
                echo 'And logic to get tag from source files for example.'
            }
        }
    }

    post {
        always {
            // The tiers bracket themselves, but a run aborted between a pre and its post phase
            // (an executor loss, abortPrevious) can leave release daemons behind. Both post
            // phases are idempotent, so running them again here costs nothing.
            runCommand 'mix post-integration-test'
            runCommand 'mix post-e2e-test'

            // One file per app per tier - see the tier mapping in config/test.exs.
            junit 'reports/junit/*.xml'

            archiveArtifacts artifacts: 'doc/**, cover/**, reports/**, apps/*/*.tar',
                             allowEmptyArchive: true,
                             fingerprint: true
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
