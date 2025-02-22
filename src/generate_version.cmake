if (EXISTS ${SOURCE_DIR}/../.git)
    execute_process(
            COMMAND git show -s --format=%ct
            WORKING_DIRECTORY ${SOURCE_DIR}
            OUTPUT_FILE ${SOURCE_DIR}/luajit_relver.txt
            RESULT_VARIABLE GIT_RESULT
    )

    if (NOT GIT_RESULT EQUAL 0)
        message(WARNING "Git show failed, using .relver")

        # TODO: This is windows only, fix this elsewhere
        execute_process(
                COMMAND type ${SOURCE_DIR}/../.relver
                WORKING_DIRECTORY ${SOURCE_DIR}
                OUTPUT_FILE ${SOURCE_DIR}/luajit_relver.txt
        )
    endif()
else()
    # TODO: This is windows only, fix this elsewhere
    execute_process(
            COMMAND type ${SOURCE_DIR}/../.relver
            WORKING_DIRECTORY ${SOURCE_DIR}
            OUTPUT_FILE ${SOURCE_DIR}/luajit_relver.txt
    )
endif()