# frozen_string_literal: true
require 'ruby_grammar_builder'
require 'walk_up'
require_relative walk_up_until("paths.rb")
require_relative './tokens.rb'

# 
# 
# create grammar!
# 
# 
# grammar = Grammar.fromTmLanguage("./original.tmLanguage.json")
grammar = Grammar.new(
    name: "CSV",
    scope_name: "text.csv",
    fileTypes: [
        "csv",
        # for example here are come C++ file extensions:
		#     "cpp",
		#     "cxx",
		#     "c++",
    ],
    version: "",
)

{
    "name": "csv syntax",
    "scopeName": "text.csv",
    "fileTypes": ["csv"],
    "patterns": [
        {
            "match": "((?: *\"(?:[^\"]*\"\")*[^\"]*\" *(?:,|$))|(?:[^,]*(?:,|$)))?((?: *\"(?:[^\"]*\"\")*[^\"]*\" *(?:,|$))|(?:[^,]*(?:,|$)))?((?: *\"(?:[^\"]*\"\")*[^\"]*\" *(?:,|$))|(?:[^,]*(?:,|$)))?((?: *\"(?:[^\"]*\"\")*[^\"]*\" *(?:,|$))|(?:[^,]*(?:,|$)))?((?: *\"(?:[^\"]*\"\")*[^\"]*\" *(?:,|$))|(?:[^,]*(?:,|$)))?((?: *\"(?:[^\"]*\"\")*[^\"]*\" *(?:,|$))|(?:[^,]*(?:,|$)))?((?: *\"(?:[^\"]*\"\")*[^\"]*\" *(?:,|$))|(?:[^,]*(?:,|$)))?((?: *\"(?:[^\"]*\"\")*[^\"]*\" *(?:,|$))|(?:[^,]*(?:,|$)))?((?: *\"(?:[^\"]*\"\")*[^\"]*\" *(?:,|$))|(?:[^,]*(?:,|$)))?((?: *\"(?:[^\"]*\"\")*[^\"]*\" *(?:,|$))|(?:[^,]*(?:,|$)))?",
            "name": "rainbowgroup",
            "captures": {
                "1": {"name": "rainbow1"},
                "2": {"name": "keyword.rainbow2"},
                "3": {"name": "entity.name.function.rainbow3"},
                "4": {"name": "comment.rainbow4"},
                "5": {"name": "string.rainbow5"},
                "6": {"name": "variable.parameter.rainbow6"},
                "7": {"name": "constant.numeric.rainbow7"},
                "8": {"name": "entity.name.type.rainbow8"},
                "9": {"name": "markup.bold.rainbow9"},
                "10": {"name": "invalid.rainbow10"}
            }
        }

    ],
    "uuid": "ca03e352-04ef-4340-9a6b-9b99aae1c418"
}


# 
#
# Setup Grammar
#
# 
    grammar[:$initial_context] = [
        :item,
    ]

# 
# Helpers
# 
    # @space
    # @spaces
    # @digit
    # @digits
    # @standard_character
    # @word
    # @word_boundary
    # @white_space_start_boundary
    # @white_space_end_boundary
    # @start_of_document
    # @end_of_document
    # @start_of_line
    # @end_of_line
    part_of_a_variable = /[a-zA-Z_][a-zA-Z_0-9]*/
    # this is really useful for keywords. eg: variableBounds[/new/] wont match "newThing" or "thingnew"
    variableBounds = ->(regex_pattern) do
        lookBehindToAvoid(@standard_character).then(regex_pattern).lookAheadToAvoid(@standard_character)
    end
    variable = variableBounds[part_of_a_variable]
    
# 
# basic patterns
# 
    grammar[:escape] = Pattern.new(
        match: /""/,
        tag_as: "constant.character.escape",
    )
    separator = ","
    generateRow = ->(column_tag:"entity.name.tag", column_number:1, children:[]) do
        PatternRange.new(
            start_pattern: Pattern.new(/(?:\G|\A)/),
            end_pattern: Pattern.new(
                tag_as: "punctuation.definition.entry",
                match: separator,
            ).or("\n"),
            apply_end_pattern_last: true,
            includes: [
                # 
                # one entry
                # 
                Pattern.new( # simple pattern
                    match: /(?:\G|\A)[^"#{separator}]*(?=#{separator}|\n)/,
                    tag_as: "string.unquoted #{column_tag} csv.column#{column_number}"
                ),
                PatternRange.new(
                    tag_as: "string.quoted.double #{column_tag} csv.column#{column_number}",
                    start_pattern: Pattern.new(
                        /(?:\G|\A)/,
                    ).then(
                        tag_as: "punctuation.definition.string",
                        match: '"',
                    ),
                    apply_end_pattern_last: true,
                    end_pattern: Pattern.new(
                        tag_as: "punctuation.definition.string",
                        match: '"',
                    ),
                    includes: [
                        :escape,
                    ],
                ),
                # 
                # subsequent entries
                # 
                *children,
            ],
        )
    end
    grammar[:item] = generateRow[column_tag:"rainbow1", column_number:1, children:[
        generateRow[column_tag:"keyword.rainbow2", column_number:2, children:[
            generateRow[column_tag:"entity.name.function.rainbow3", column_number:3, children:[
                generateRow[column_tag:"comment.rainbow4", column_number:4, children:[
                    generateRow[column_tag:"string.rainbow5", column_number:5, children:[
                        generateRow[column_tag:"variable.parameter.rainbow6", column_number:6, children:[
                            generateRow[column_tag:"constant.numeric.rainbow7", column_number:7, children:[
                                generateRow[column_tag:"entity.name.type.rainbow8", column_number:8, children:[
                                    generateRow[column_tag:"markup.bold.rainbow9", column_number:9, children:[
                                        generateRow[column_tag:"invalid.rainbow10", column_number:10, children:[
                                        ]]
                                    ]]
                                ]]
                            ]]
                        ]]
                    ]]
                ]]
            ]]
        ]]
    ]]

#
# Save
#
name = "csv"
grammar.save_to(
    syntax_name: name,
    syntax_dir: "./autogenerated",
    tag_dir: "./autogenerated",
)