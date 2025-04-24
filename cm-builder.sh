#!/bin/bash

# Deploy a single DevFile to OpenShift
# ./cm-builder.sh devfile-cm stacks/kemo-armillary/1.0.0/devfile.yaml | oc apply -f -
# Deploy a Stack to OpenShift
# ./cm-builder.sh stack-cm stacks/kemo-armillary/stack.yaml | oc apply -f -

DEVSPACES_NAMESPACE="devspaces"

function readStack {
    STACK_FILE=${1}
    STACK_DIR=$(dirname $STACK_FILE)
    VERSIONS=$(yq -rM -o=json .versions $STACK_FILE)
    TMP_EMPTY_JSON_FILE=$(mktemp)
    echo '[]' > $TMP_EMPTY_JSON_FILE

    echo $VERSIONS | jq -c '.[]' | while read i; do
        VERSION=$(echo $i | jq -r .version)
        TMP_FILE=$(mktemp)
        if [ -f "$STACK_DIR/${VERSION}/devfile.yaml" ]; then
            processDevFile $STACK_DIR/${VERSION}/devfile.yaml | jq -rcM > $TMP_FILE
        elif [ -f "$STACK_DIR/${VERSION}/devfile.yml" ]; then
            processDevFile $STACK_DIR/${VERSION}/devfile.yml | jq -rcM > $TMP_FILE
        else
            echo "Devfile not found for $VERSION"
            exit 1
        fi
        ADD_JSON="$(jq '. += input' $TMP_EMPTY_JSON_FILE $TMP_FILE)"
        echo "$ADD_JSON" > $TMP_EMPTY_JSON_FILE
        rm -f $TMP_FILE
    done

    cat $TMP_EMPTY_JSON_FILE

    rm -f $TMP_EMPTY_JSON_FILE
}

function processDevFile {
    DEV_FILE=${1}

    DISPLAY_NAME=$(yq -rM .metadata.displayName $DEV_FILE)
    DESCRIPTION=$(yq -rM .metadata.description $DEV_FILE)
    DESCRIPTION=$(yq -rM .metadata.description $DEV_FILE)
    TAGS=$(yq -rM -o=json .metadata.tags $DEV_FILE)
    URL=$(yq -rM .metadata.source $DEV_FILE)
    ICON=$(yq -rM .metadata.icon $DEV_FILE)
    ICON_B64=$(curl -s $ICON | base64 -w0)
    ICON_TYPE=$(curl -XHEAD -s  -w '%{content_type}' $ICON)
    VERSION=$(yq -rM .metadata.version $DEV_FILE)

    cat <<EOF
[{"displayName": "$DISPLAY_NAME", "description": "v${VERSION} - $DESCRIPTION", "tags": $TAGS, "url": "$URL", "icon": { "base64data": "$ICON_B64", "mediatype": "$ICON_TYPE" }}]
EOF
}

function createConfigMapForStack {
    STACK_FILE=${1}
    STACK_PREFIX="${2}"
    STACK_NAME=$(yq -rM .name $STACK_FILE)
    TMP_EMPTY_JSON_FILE=$(mktemp)
    JSON_OUT=$(readStack ${STACK_FILE})
    echo "$JSON_OUT" > $TMP_EMPTY_JSON_FILE
    oc create configmap ${STACK_PREFIX}${STACK_NAME} -n ${DEVSPACES_NAMESPACE} -o yaml --dry-run=client --from-file=${STACK_PREFIX}${STACK_NAME}.json=$TMP_EMPTY_JSON_FILE \
    | yq -rM '.metadata += {"labels": {"app.kubernetes.io/part-of": "che.eclipse.org", "app.kubernetes.io/component": "getting-started-samples"}}'
}

function createConfigMapForDevfile {
    DEV_FILE=${1}
    DEV_PREFIX="${2}"
    DEVFILE_NAME=$(yq -rM .metadata.name $DEV_FILE)
    TMP_EMPTY_JSON_FILE=$(mktemp)
    JSON_OUT=$(processDevFile ${DEV_FILE})
    echo "$JSON_OUT" > $TMP_EMPTY_JSON_FILE
    oc create configmap ${DEV_PREFIX}${DEVFILE_NAME} -n ${DEVSPACES_NAMESPACE} -o yaml --dry-run=client --from-file=${DEV_PREFIX}${DEVFILE_NAME}.json=$TMP_EMPTY_JSON_FILE \
    | yq -rM '.metadata += {"labels": {"app.kubernetes.io/part-of": "che.eclipse.org", "app.kubernetes.io/component": "getting-started-samples"}}'
}

if [ "${1}" == "stack" ]; then
    readStack ${2}
fi
if [ "${1}" == "devfile" ]; then
    processDevFile ${2}
fi

if [ "${1}" == "stack-cm" ]; then
    createConfigMapForStack ${2}
fi

if [ "${1}" == "devfile-cm" ]; then
    createConfigMapForDevfile ${2}
fi
