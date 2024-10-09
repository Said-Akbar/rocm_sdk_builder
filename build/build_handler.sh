#!/bin/bash

source build/system_utils.sh
source build/config.sh
source build/build_func.sh

func_babs_handle_build() {
    func_env_variables_print #From config.sh
    func_install_dir_init ${INSTALL_DIR_PREFIX_SDK_AI_MODELS}
    func_install_dir_init ${INSTALL_DIR_PREFIX_SDK_ROOT}
    local ret_val=$?
    if [[ $ret_val -eq 0 ]]; then
        if [[ -n "$1" ]]; then
            source ./build/build_func.sh
            if [[ "$1" = *.binfo ]] ; then
                func_init_and_build_single_binfo $1
            fi
            if [[ "$1" = *.blist ]] ; then
                func_init_and_build_blist $1
            fi
        else
            source ./build/build_core.sh
        fi
        res=$?
        if [[ $res -eq 0 ]]; then
            echo -e "\nROCM SDK build and install ready"
            func_is_user_in_dev_kfd_render_group #From system_utils.sh
            res=$?
            if [ ${res} -eq 0 ]; then
                echo "You can use the following commands to test your gpu is detected:"
            else
                echo "After fixing /dev/kff permission problems, you can use the following commands to test that your gpu"
            fi
            echo ""
            echo "    source ${INSTALL_DIR_PREFIX_SDK_ROOT}/bin/env_rocm.sh"
            echo "    rocminfo"
            echo ""
        else
            echo -e "Failed to build ROCM_SDK_BUILDER"
            echo ""
        fi
    fi
}

func_babs_handle_build_direcory_clean() {
    func_env_variables_print #From config.sh
    func_install_dir_init ${INSTALL_DIR_PREFIX_SDK_AI_MODELS}
    func_install_dir_init ${INSTALL_DIR_PREFIX_SDK_ROOT}
    local ret_val=$?
    if [[ $ret_val -eq 0 ]]; then
        if [[ -n "$1" ]]; then
            source ./build/build_func.sh
            if [[ "$1" = *.binfo ]] ; then
                func_clean_build_directory_single_binfo $1
            fi
            if [[ "$1" = *.blist ]] ; then
                func_clean_build_directories_blist $1
            fi
        else
            # verify the clean of whole core build
            read -p "Are you sure that you want to clean ROCM SDK Builder core build directories (y/n)? " -r
            echo    # (optional) move to a new line
            if [[ $REPLY =~ ^[Yy]$ ]]
            then
                func_clean_build_directories_core
            else
                echo "ROCM SDK Builder core build directory clean canceled."
                echo ""
                exit 1
            fi
        fi
        res=$?
        if [[ $res -eq 0 ]]; then
            echo -e "\nROCM SDK Builder cleaned build directories succesfully."
            echo ""
        else
            echo -e "Failed to clean ROCM SDK Builder build directories."
            echo ""
        fi
    fi
}

func_babs_handle_checkout() {
    if [[ -n "$1" ]]; then
        echo "func_babs_handle_checkout param: $1"
        if [[ "$1" = *.binfo ]] ; then
            func_envsetup_init
            func_babs_checkout_by_binfo $1
        fi
        if [[ "$1" = *.blist ]] ; then
            func_envsetup_init
            func_babs_checkout_by_blist $1
        fi
    else
        echo "func_babs_handle_checkout no params"
        func_repolist_checkout_default_versions
    fi
}

func_babs_handle_apply_patches() {
    if [[ -n "$1" ]]; then
        echo "func_babs_handle_patch_apply param: $1"
        if [[ "$1" = *.binfo ]] ; then
            local CUR_BINFO_FNAME="$1"
            func_envsetup_init
            func_babs_apply_patches_by_binfo ${CUR_BINFO_FNAME} #From build/binfo_operations.sh
        fi
        if [[ "$1" = *.blist ]] ; then
            local CUR_BLIST_FNAME="$1"
            func_envsetup_init
            func_babs_apply_patches_by_blist ${CUR_BLIST_FNAME} #From build/binfo_operations.sh
        fi
    else
        echo "func_babs_handle_patch_apply no params"
        func_repolist_apply_patches build/binfo_operations.sh
    fi
}

func_babs_handle_checkout_and_apply_patches() {
    if [[ -n "$1" ]]; then
        echo "func_babs_handle_checkout_and_apply_patches param: $1"
        if [[ "$1" = *.binfo ]] ; then
            local CUR_BINFO_FNAME="$1"
            func_envsetup_init
            func_babs_checkout_by_binfo ${CUR_BINFO_FNAME}
            func_babs_apply_patches_by_binfo ${CUR_BINFO_FNAME}
        fi
        if [[ "$1" = *.blist ]] ; then
            local CUR_BLIST_FNAME="$1"
            func_envsetup_init
            func_babs_checkout_by_blist ${CUR_BLIST_FNAME}
            func_babs_apply_patches_by_blist ${CUR_BLIST_FNAME}
        fi
    else
        func_repolist_checkout_default_versions
        func_repolist_apply_patches
    fi
}

RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR=0
RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION=${UPSTREAM_REPO_VERSION_TAG_DEFAULT}
func_babs_get_update_hashcodes_by_binfo() {
    if [[ -n "$1" ]]; then
        #echo "func_babs_get_update_hashcodes_by_binfo param: $1"
        if [[ "$1" = *.binfo ]] ; then
            APP_INFO_FULL_NAME="$1"
            unset BINFO_APP_NAME
            BINFO_APP_UPSTREAM_REPO_VERSION_TAG=${UPSTREAM_REPO_VERSION_TAG_DEFAULT}
            source ${APP_INFO_FULL_NAME}
            local CUR_APP_PATCH_DIR="${PATCH_FILE_ROOT_DIR}/${BINFO_APP_NAME}"
            RET_FOR_FUNC_GET_BINFO_HASH=0
            if [ -d ${CUR_APP_PATCH_DIR} ]; then
                RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR=$(sha1sum ${CUR_APP_PATCH_DIR}/* | sha1sum)
            fi
            #RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION=${BINFO_APP_UPSTREAM_REPO_VERSION_TAG}
            RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION=$(sha1sum ${APP_INFO_FULL_NAME})
        fi
    fi
}

func_babs_handle_update() {
	local binfo_project_has_updates=0
	local blist_projects_has_updates=0
	local core_projects_has_updates=0
	local git_update_done=0
	local ii=0
	declare -A DICTIONARY_ORIG_APP_PATCH_DIR_CHECKSUMS
    declare -A DICTIONARY_ORIG_APP_BINFO_CHECKSUM
    declare -A DICTIONARY_UPDATED_APP_PATCH_DIR_CHECKSUMS
    declare -A DICTIONARY_UPDATED_APP_BINFO_CHECKSUM

    echo "ROCM SDK Builder update started"
    # check first binfo and patch dir hashcodes for all core projects before git pull is done
	func_build_env_init
    ii=0
    while [ "x${LIST_BINFO_FILE_FULLNAME[ii]}" != "x" ]
    do
        local CUR_BINFO_FNAME=${LIST_BINFO_FILE_FULLNAME[${ii}]}
        cd ${SDK_ROOT_DIR}
        RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR=0
        RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION=${UPSTREAM_REPO_VERSION_TAG_DEFAULT}
        func_babs_get_update_hashcodes_by_binfo ${CUR_BINFO_FNAME}
        DICTIONARY_ORIG_APP_PATCH_DIR_CHECKSUMS[${CUR_BINFO_FNAME}]=${RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR}
        DICTIONARY_ORIG_APP_BINFO_CHECKSUM[${CUR_BINFO_FNAME}]=${RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION}
        #echo "LIST_BINFO_FILE_FULLNAME[${ii}]: ${LIST_BINFO_FILE_FULLNAME[${ii}]}"
        #func_clean_build_directory_single_binfo ${LIST_BINFO_FILE_FULLNAME[${ii}]} ${ii}
        ii=$(( ${ii} + 1 ))
    done
    func_build_env_deinit
    
    # then check the optionally the projects in binfo or blist file
	if [[ -n "$1" ]]; then
        #echo "func_babs_handle_update param: $1"
        if [[ "$1" = *.binfo ]] ; then
            local CUR_BINFO_FNAME="$1"
            #echo "update binfo"
            # check hashcodes for versions and patchdirs before the git pull
            RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR=0
            RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION=${UPSTREAM_REPO_VERSION_TAG_DEFAULT}
            func_babs_get_update_hashcodes_by_binfo ${CUR_BINFO_FNAME}
            DICTIONARY_ORIG_APP_PATCH_DIR_CHECKSUMS[${CUR_BINFO_FNAME}]=${RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR}
            DICTIONARY_ORIG_APP_BINFO_CHECKSUM[${CUR_BINFO_FNAME}]=${RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION}
            
            # update to latest version and check again if some projects needs to be cleaned
            git pull
            git_update_done=1
            
            RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR=0
            RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION=${UPSTREAM_REPO_VERSION_TAG_DEFAULT}
            func_babs_get_update_hashcodes_by_binfo ${CUR_BINFO_FNAME}
            DICTIONARY_UPDATED_APP_PATCH_DIR_CHECKSUMS[${CUR_BINFO_FNAME}]=${RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR}
            DICTIONARY_UPDATED_APP_BINFO_CHECKSUM[${CUR_BINFO_FNAME}]=${RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION}
            echo $RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION
            
            local ORIG_PATCH_DIR_HASHCODE=${DICTIONARY_ORIG_APP_PATCH_DIR_CHECKSUMS[${CUR_BINFO_FNAME}]}
            local ORIG_APP_BINFO_CHECKSUM=${DICTIONARY_ORIG_APP_BINFO_CHECKSUM[${CUR_BINFO_FNAME}]}
            local UPDATED_PATCH_DIR_HASHCODE=${DICTIONARY_UPDATED_APP_PATCH_DIR_CHECKSUMS[${CUR_BINFO_FNAME}]}
            local UPDATED_APP_BINFO_CHECKSUM=${DICTIONARY_UPDATED_APP_BINFO_CHECKSUM[${CUR_BINFO_FNAME}]}
            #echo "ORIG_PATCH_DIR_HASHCODE ${ORIG_PATCH_DIR_HASHCODE}"
            #echo "ORIG_APP_BINFO_CHECKSUM ${ORIG_APP_BINFO_CHECKSUM}"
            #echo "UPDATED_PATCH_DIR_HASHCODE ${UPDATED_PATCH_DIR_HASHCODE}"
            #echo "UPDATED_APP_BINFO_CHECKSUM ${UPDATED_APP_BINFO_CHECKSUM}"
            if [[ ${ORIG_PATCH_DIR_HASHCODE} == ${UPDATED_PATCH_DIR_HASHCODE} && ${ORIG_APP_BINFO_CHECKSUM} == ${UPDATED_APP_BINFO_CHECKSUM} ]]; then
                echo "${CUR_BINFO_FNAME}, no updates, no rebuild needed"
                binfo_project_has_updates=1
            else
                ./babs.sh --clean ${CUR_BINFO_FNAME}
				func_envsetup_init
				func_babs_checkout_by_binfo ${CUR_BINFO_FNAME}
				cd ${SDK_ROOT_DIR}
				func_babs_apply_patches_by_binfo ${CUR_BINFO_FNAME}
				binfo_project_has_updates=2
            fi
        else
            if [[ "$1" = *.blist ]] ; then
                #echo "update blist"
                local CUR_BLIST_FNAME="$1"
                local BINFO_ARRAY

                ii=0
                readarray -t BINFO_ARRAY < $1
                if [[ ${BINFO_ARRAY[@]} ]]; then
                    local CUR_BINFO_FNAME
                    for CUR_BINFO_FNAME in "${BINFO_ARRAY[@]}"; do
                        if [ ! -z ${CUR_BINFO_FNAME} ]; then
                            if  [ -z ${CUR_BINFO_FNAME##*.binfo} ]; then
                                #echo "CUR_BINFO_FNAME: ${CUR_BINFO_FNAME}"
                                cd ${SDK_ROOT_DIR}
                                RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR=0
                                RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION=${UPSTREAM_REPO_VERSION_TAG_DEFAULT}
                                func_babs_get_update_hashcodes_by_binfo ${CUR_BINFO_FNAME}
                                DICTIONARY_ORIG_APP_PATCH_DIR_CHECKSUMS[${CUR_BINFO_FNAME}]=${RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR}
                                DICTIONARY_ORIG_APP_BINFO_CHECKSUM[${CUR_BINFO_FNAME}]=${RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION}
                                ii=$(( ${ii} + 1 ))
                            fi
                        fi
                    done
                fi
                # update
                git pull
                git_update_done=1
                # read the blist file again as it may have been changed
                ii=0
                readarray -t BINFO_ARRAY < $1
                if [[ ${BINFO_ARRAY[@]} ]]; then
                    local CUR_BINFO_FNAME
                    # and then check again each binfo file if version or patch dir has changed
                    for CUR_BINFO_FNAME in "${BINFO_ARRAY[@]}"; do
                        if [ ! -z ${CUR_BINFO_FNAME} ]; then
                            if  [ -z ${CUR_BINFO_FNAME##*.binfo} ]; then
                                #echo "CUR_BINFO_FNAME: ${CUR_BINFO_FNAME}"
                                cd ${SDK_ROOT_DIR}
                                RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR=0
                                RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION=${UPSTREAM_REPO_VERSION_TAG_DEFAULT}
                                func_babs_get_update_hashcodes_by_binfo ${CUR_BINFO_FNAME}
                                DICTIONARY_UPDATED_APP_PATCH_DIR_CHECKSUMS[${CUR_BINFO_FNAME}]=${RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR}
                                DICTIONARY_UPDATED_APP_BINFO_CHECKSUM[${CUR_BINFO_FNAME}]=${RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION}
                                 
                                local ORIG_PATCH_DIR_HASHCODE=${DICTIONARY_ORIG_APP_PATCH_DIR_CHECKSUMS[${CUR_BINFO_FNAME}]}
                                local ORIG_APP_BINFO_CHECKSUM=${DICTIONARY_ORIG_APP_BINFO_CHECKSUM[${CUR_BINFO_FNAME}]}
                                local UPDATED_PATCH_DIR_HASHCODE=${DICTIONARY_UPDATED_APP_PATCH_DIR_CHECKSUMS[${CUR_BINFO_FNAME}]}
                                local UPDATED_APP_BINFO_CHECKSUM=${DICTIONARY_UPDATED_APP_BINFO_CHECKSUM[${CUR_BINFO_FNAME}]}
                                #echo "ORIG_PATCH_DIR_HASHCODE ${ORIG_PATCH_DIR_HASHCODE}"
                                #echo "ORIG_APP_BINFO_CHECKSUM ${ORIG_APP_BINFO_CHECKSUM}"
                                #echo "UPDATED_PATCH_DIR_HASHCODE ${UPDATED_PATCH_DIR_HASHCODE}"
                                #echo "UPDATED_APP_BINFO_CHECKSUM ${UPDATED_APP_BINFO_CHECKSUM}"
                                if [[ ${ORIG_PATCH_DIR_HASHCODE} == ${UPDATED_PATCH_DIR_HASHCODE} && ${ORIG_APP_BINFO_CHECKSUM} == ${UPDATED_APP_BINFO_CHECKSUM} ]]; then
                                    # do null / no-op command with ':'-character as we do not want to echo anything
                                    :
                                    #echo "${CUR_BINFO_FNAME}, no updates, no rebuild needed"
                                    blist_projects_has_updates=1
                                else
                                    # clean, checkout and apply patches only to modified blist projects
                                    echo "${CUR_BINFO_FNAME} updated, rebuild recommended"
                                    ./babs.sh --clean ${CUR_BINFO_FNAME}
                                    func_envsetup_init
                                    func_babs_checkout_by_binfo ${CUR_BINFO_FNAME} ${ii}
                                    cd ${SDK_ROOT_DIR}
                                    func_babs_apply_patches_by_binfo ${CUR_BINFO_FNAME} ${ii}
                                    blist_projects_has_updates=2
                                fi
                                ii=$(( ${ii} + 1 ))                                
                            fi
                        fi
                    done
                    # checkout and ca done above only for the changed projects
                    #func_envsetup_init
                    #func_babs_checkout_by_blist ${CUR_BLIST_FNAME}
                    #func_babs_apply_patches_by_blist ${CUR_BLIST_FNAME}
                else
                    echo ""
                    echo "Failed to checkout repositories by using the blist file."
                    echo "Could not find binfo files listed in:"
                    echo "    $1"
                    echo ""
                    exit 1
                fi            
                #func_envsetup_init
                #func_babs_checkout_by_blist ${ARG__USER_CMD_PARAM1}
                #func_babs_apply_patches_by_blist ${ARG__USER_CMD_PARAM1}
            else
                echo "unknown parameter"
            fi
        fi
    fi

    # update rocm sdk builder source code to latest version in this git repo if it's not already done above
    if [ $git_update_done == 0 ]; then
        git pull
    fi

    # then check hashes from updated core projects
    func_build_env_init
    ii=0
    while [ "x${LIST_BINFO_FILE_FULLNAME[ii]}" != "x" ]
    do
        local CUR_BINFO_FNAME=${LIST_BINFO_FILE_FULLNAME[${ii}]}
        cd ${SDK_ROOT_DIR}
        RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR=0
        RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION=${UPSTREAM_REPO_VERSION_TAG_DEFAULT}
        func_babs_get_update_hashcodes_by_binfo ${CUR_BINFO_FNAME}
        DICTIONARY_UPDATED_APP_PATCH_DIR_CHECKSUMS[${CUR_BINFO_FNAME}]=${RET_GET_UPDATE_HASHCODES_BY_BINFO__PATCH_DIR}
        DICTIONARY_UPDATED_APP_BINFO_CHECKSUM[${CUR_BINFO_FNAME}]=${RET_GET_UPDATE_HASHCODES_BY_BINFO__APP_VERSION}

        local ORIG_PATCH_DIR_HASHCODE=${DICTIONARY_ORIG_APP_PATCH_DIR_CHECKSUMS[${CUR_BINFO_FNAME}]}
        local ORIG_APP_BINFO_CHECKSUM=${DICTIONARY_ORIG_APP_BINFO_CHECKSUM[${CUR_BINFO_FNAME}]}
        local UPDATED_PATCH_DIR_HASHCODE=${DICTIONARY_UPDATED_APP_PATCH_DIR_CHECKSUMS[${CUR_BINFO_FNAME}]}
        local UPDATED_APP_BINFO_CHECKSUM=${DICTIONARY_UPDATED_APP_BINFO_CHECKSUM[${CUR_BINFO_FNAME}]}
        #echo "CUR_BINFO_FNAME: ${CUR_BINFO_FNAME}"
        #echo "ORIG_PATCH_DIR_HASHCODE ${ORIG_PATCH_DIR_HASHCODE}"
        #echo "ORIG_APP_BINFO_CHECKSUM ${ORIG_APP_BINFO_CHECKSUM}"
        #echo "UPDATED_PATCH_DIR_HASHCODE ${UPDATED_PATCH_DIR_HASHCODE}"
        #echo "UPDATED_APP_BINFO_CHECKSUM ${UPDATED_APP_BINFO_CHECKSUM}"
        if [[ ${ORIG_PATCH_DIR_HASHCODE} == ${UPDATED_PATCH_DIR_HASHCODE} && ${ORIG_APP_BINFO_CHECKSUM} == ${UPDATED_APP_BINFO_CHECKSUM} ]]; then
            # do null / no-op command with ':'-character as we do not want to echo anything
            :
            #echo "${CUR_BINFO_FNAME}, no updates, no rebuild needed"
        else
            # clean, checkout and apply patches only to modified core projects
            echo "${CUR_BINFO_FNAME} updated, rebuild needed"
            ./babs.sh --clean ${CUR_BINFO_FNAME}
            func_envsetup_init
            func_babs_checkout_by_binfo ${CUR_BINFO_FNAME} ${ii}
            cd ${SDK_ROOT_DIR}
            func_babs_apply_patches_by_binfo ${CUR_BINFO_FNAME} ${ii}
            core_projects_has_updates=1
        fi
        ii=$(( ${ii} + 1 ))
    done
    echo ""
    if [ ${binfo_project_has_updates} == 1 ]; then
        echo "No changes in project $1"
    fi
    if [ ${binfo_project_has_updates} == 2 ]; then
        echo "$1 has updates, rebuild recommended with command:"
        echo "./babs.sh -b $1"
    fi
    if [ ${blist_projects_has_updates} == 1 ]; then
        echo "No changes in projects listed in $1"
    fi
    if [ ${blist_projects_has_updates} == 2 ]; then
        echo "$1 projects has been updated, rebuild recommended with command:"
        echo "./babs.sh -b $1"
    fi
    if [ ${core_projects_has_updates} == 1 ]; then
        echo "Core brojects has been updated, rebuild recommended with command:"
        echo "./babs.sh -b"
    else
        echo "No changes in core projects."
    fi
    echo "ROCM SDK Builder source code update ready"
    echo ""
    # no need to checkout and apply patches to all core projects, only modified one updated above
    #func_build_env_deinit
    #func_repolist_checkout_default_versions
	#func_repolist_apply_patches
}

func_babs_handle_repository_fetch() {
    if [[ -n "$1" ]]; then
        echo "func_babs_handle_fetch param: $1"
        if [[ "$1" = *.binfo ]] ; then
            func_envsetup_init
            # if new repo is created, apply also patches
            func_babs_init_and_fetch_by_binfo "$1" 0
        fi
        if [[ "$1" = *.blist ]] ; then
            func_envsetup_init
            # if new repo is created, apply also patches
            func_babs_init_and_fetch_by_blist "$1" 0
        fi
    else
        # if new repo is created, apply also patches
        func_repolist_init_and_fetch_core_repositories 0
    fi
}

# todo: Check whether these functions used here can be replaced with the ones
# on func_babs_handle_repository_fetch
# because the functionality in these functions is now most likely exactly similar
# than in the fetch functions. Fetch functions has been updated to
# handle the checkout, apply patches and submodules also if the repositories does not exist.
func_babs_handle_repository_init() {
    if [[ -n "$1" ]]; then
        echo "func_babs_handle_init param: $1"
        if [[ "$1" = *.binfo ]] ; then
            func_envsetup_init
            func_upstream_remote_repo_add_by_binfo "$1"
        fi
        if [[ "$1" = *.blist ]] ; then
            func_envsetup_init
            func_upstream_remote_repo_add_by_blist "$1"
        fi
    else
        func_repolist_upstream_remote_repo_add #From build/repo_management.sh
    fi
}
