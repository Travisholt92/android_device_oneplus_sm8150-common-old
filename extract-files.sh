#!/bin/bash
#
# Copyright (C) 2018-2019 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

KANGOS_ROOT="${MY_DIR}"/../../..

HELPER="${KANGOS_ROOT}/vendor/kangos/build/tools/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

function blob_fixup() {
    case "${1}" in
    system_ext/lib64/libwfdnative.so | system_ext/lib64/libwfdnative.so)
         sed -i "s/android.hidl.base@1.0.so/libhidlbase.so\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00/" "${2}"
         ;;
    system_ext/etc/permissions/qti_libpermissions.xml)
        sed -i -e 's|name=\"android.hidl.manager-V1.0-java|name=\"android.hidl.manager@1.0-java|g' "${2}"
        ;;
    vendor/lib/hw/camera.qcom.so | vendor/lib64/hw/camera.qcom.so)
        sed -i "s/libhidltransport.so/qtimutex.so\x00\x00\x00\x00\x00\x00\x00\x00/" "${2}"
        ;;
    esac
}

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

SECTION=
KANG=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

# Initialize the helper for common device
setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${KANGOS_ROOT}" true "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" \
        "${KANG}" --section "${SECTION}"

if [ -s "${MY_DIR}/../${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${KANGOS_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../${DEVICE}/proprietary-files.txt" "${SRC}" \
            "${KANG}" --section "${SECTION}"
fi

COMMON_BLOB_ROOT="${KANGOS_ROOT}/vendor/${VENDOR}/${DEVICE_COMMON}/proprietary"

"${MY_DIR}/setup-makefiles.sh"

#
# Fix xml version
#
function fix_xml_version () {
    sed -i \
        's/xml version="2.0"/xml version="1.0"/' \
        "$DEVICE_BLOB_ROOT"/"$1"
}

fix_xml_version product/etc/permissions/vendor.qti.hardware.data.connection-V1.0-java.xml
fix_xml_version product/etc/permissions/vendor.qti.hardware.data.connection-V1.1-java.xml

"${MY_DIR}/setup-makefiles.sh"

for i in $(grep -rn 'libhidltransport.so\|libhwbinder.so' ../../../vendor/${VENDOR}/"${DEVICE_COMMON}"/proprietary | awk '{print $4}'); do
	patchelf --remove-needed "libhwbinder.so" "$i"
	patchelf --remove-needed "libhidltransport.so" "$i"
done

for i in $(grep -rn 'libhidltransport.so\|libhwbinder.so' ../../../vendor/${VENDOR}/"${DEVICE}"/proprietary | awk '{print $4}'); do
	patchelf --remove-needed "libhwbinder.so" "$i"
	patchelf --remove-needed "libhidltransport.so" "$i"
done
