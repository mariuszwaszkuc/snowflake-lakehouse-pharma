{% macro drop_orphans(database, schema) %}

    {% if execute %}

        {{ log("Starting orphan cleanup for " ~ database ~ "." ~ schema, info=True) }}

        -- 1. DBT MODELS (ONLY NAMES)
        {% set dbt_models = [] %}

        {% for node in graph.nodes.values() %}
            {% if node.resource_type == 'model' %}
                {% do dbt_models.append((node.alias or node.name) | lower) %}
            {% endif %}
        {% endfor %}

        -- 2. GET OBJECTS FROM SNOWFLAKE
        {% set existing_query %}
            select table_name, table_type
            from {{ database }}.information_schema.tables
            where table_schema = upper('{{ schema }}')
        {% endset %}

        {% set results = run_query(existing_query) %}

        {% if results is none %}
            {{ exceptions.raise_compiler_error("No objects found or invalid permissions") }}
        {% endif %}

        -- 3. PROCESS OBJECTS
        {% for row in results %}

            {% set object_name = row[0] | lower %}
            {% set object_type = row[1] | lower | trim %}

            {% if object_name not in dbt_models %}

                {{ log("Dropping orphan: " ~ object_type ~ " -> " ~ database ~ "." ~ schema ~ "." ~ object_name, info=True) }}

                -- TABLE
                {% if object_type == 'base table' %}

                    {% do run_query(
                        "drop table if exists " ~ database ~ "." ~ schema ~ "." ~ object_name
                    ) %}

                -- VIEW
                {% elif object_type == 'view' %}

                    {% do run_query(
                        "drop view if exists " ~ database ~ "." ~ schema ~ "." ~ object_name
                    ) %}

                -- MATERIALIZED VIEW (optional support)
                {% elif object_type == 'materialized view' %}

                    {% do run_query(
                        "drop materialized view if exists " ~ database ~ "." ~ schema ~ "." ~ object_name
                    ) %}

                {% else %}

                    {{ log("Skipping unsupported object type: " ~ object_type, info=True) }}

                {% endif %}

            {% else %}

                {{ log("Keeping dbt-managed object: " ~ object_name, info=True) }}

            {% endif %}

        {% endfor %}

    {% endif %}

{% endmacro %}