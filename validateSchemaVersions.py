#!/usr/bin/env python3
#**********************************************************************
# Copyright 2024 Crown Copyright
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#**********************************************************************


#**********************************************************************
# Script to ensure all the version numbers in the detection
# XMLSchema are valid
#**********************************************************************


import os
import re
import sys
import xml.etree.ElementTree as ET

SCHEMA_FILENAME = "detection.xsd"

root_path = os.path.dirname(os.path.realpath(__file__))

def getMinorVersion(versionStr):
    minorVer = re.match("[0-9]*\\.([0-9]*)[.-].*", versionStr).group(1)
    return minorVer

def validateVersions(newVersion, schemaFile):

    if (newVersion):
        newVersionNum = re.sub(r'^v', "", newVersion)
        print("Gradle build version: %s" % newVersionNum)

    if (not schemaFile):
        schemaFile = SCHEMA_FILENAME

    if (not os.path.isfile(schemaFile)):
        print("ERROR - Schema file %s doesn't exist" % schemaFile)
        exit(1)

    print("")
    print("Validating file %s" % schemaFile)

    # pattern = re.compile("xmlns:evt\"event-logging:.*\"")
    xsdFile = open(schemaFile, 'r')
    filetext = xsdFile.read()
    xsdFile.close()
    matches = re.findall("xmlns:det=\"detection:([^\"]*)\"", filetext)
    if (len(matches) != 1):
        raise ValueError("Unexpected matches for evt namespace", matches)
    namespaceVersion = matches[0]
    print("namespace version: [%s]" % namespaceVersion)

    xml_root = ET.parse(schemaFile).getroot()

    targetNamespaceAttr = xml_root.get("targetNamespace")
    targetNamespaceVersion = re.match(".*:(.*)$", targetNamespaceAttr).group(1)
    print("targetNamespace:   [%s]" % targetNamespaceVersion)

    versionAttrVersion = xml_root.get("version")
    print("version:           [%s]" % versionAttrVersion)

    idAttr = xml_root.get("id")
    idAttrVersion = re.match("detection-v?(.*)$", idAttr).group(1)
    print("id:                [%s]" % idAttrVersion)

    print("")
    versionRegex = "[0-9]+\\.[0-9]+(\\.[0-9]+|-(alpha|beta)\\.[0-9]+)"

    if (newVersion and not re.match(".*SNAPSHOT", newVersionNum)):
        if (versionAttrVersion != newVersionNum):
            raise ValueError("version attribute and planned version do not match", versionAttrVersion, newVersionNum)

        if (not re.match(versionRegex, versionAttrVersion)):
            raise ValueError("version attribute does not match the valid regex", versionAttrVersion, versionRegex)

        # In an ideal world we would increment the namespace version when we make
        # a breaking change to the schema but that has all sorts of implications
        # on existing pipelines, xslts and content packs that would all need changing.
        if (not versionAttrVersion.startswith(targetNamespaceVersion)):
            print("Major version of the version attribute %s does not match the targetNamespace version %s" % (versionAttrVersion, targetNamespaceVersion))
            # raise ValueError("Major version of the version attribute does not match the targetNamespace version", versionAttrVersion, targetNamespaceVersion)

        minorVer = getMinorVersion(versionAttrVersion)

    # print enumVersions

    if (namespaceVersion != targetNamespaceVersion):
        raise ValueError("namespace version and targetNamespace version do not match", namespaceVersion, targetNamespaceVersion)

    if (versionAttrVersion != idAttrVersion):
        raise ValueError("version attribute and id attribute do not match", versionAttrVersion, idAttrVersion)




# Script starts here
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
print(sys.argv)

if len(sys.argv) == 2:
    newVersion = sys.argv[1]
    schemaFile = None
elif len(sys.argv) == 3:
    newVersion = sys.argv[1]
    schemaFile = sys.argv[2]
else:
    newVersion = None
    schemaFile = None

print("version [%s], schema file [%s]" % (newVersion, schemaFile))
    
validateVersions(newVersion, schemaFile)

print("")
print("Done!")
exit(0)
