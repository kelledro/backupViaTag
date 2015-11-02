#~/bin/bash
base64 backupViaTag | awk '{printf "\t\t\t\t\t\"%s\\n\",\n", $0}' > /tmp/backupViaTag.b64 && sed '/<<base64script>>/{
    s/<<base64script>>//
    r /tmp/backupViaTag.b64
}' backupViaTag.template.template 
