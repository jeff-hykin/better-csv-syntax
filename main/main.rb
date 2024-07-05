# frozen_string_literal: true
require 'ruby_grammar_builder'
require 'walk_up'
require_relative walk_up_until("paths.rb")
require_relative './tokens.rb'
require 'json'

# 
# grab info out of the package.json
# 
package_info = JSON.parse(IO.read(File.join(__dir__, "..", "package.json")))
lang_info    = package_info["contributes"]["languages"]
grammar_info = package_info["contributes"]["grammars"]
supported = {
    "csv"=> ",",
    "tsv"=> "\t",
    "csv (pipe)"=> "|",
    "csv (tilde)"=> "~",
    "csv (caret)"=> "^",
    "csv (colon)"=> ":",
    "csv (equals)"=> "=",
    "csv (dot)"=> ".",
    "csv (hyphen)"=> "'",
    "csv (semicolon)"=> ";",
    # not supported:
    # "csv (whitespace)": " ",
    # "csv (double quote)": "dbqsv",
    # "dynamic csv": "dynamic_csv",
    # "rainbow hover markup": "rb_hover",
}

# 
# generate one entry per language
# 
kinds = supported.keys.map do |lang_id|
    this_grammar = grammar_info.find { |grammar| grammar["language"] == lang_id }
    this_language = lang_info.find { |lang| lang["id"] == lang_id }
    file_name = File.basename(this_grammar["path"]).gsub(/.tmLanguage.json$/, "")
    {
        grammar_name: lang_id,
        file_name: file_name,
        scope_name: this_grammar["scopeName"],
        fileTypes: this_language["extensions"] + [".#{file_name}"],
        separator: supported[lang_id],
    }
end

# 
# generate the grammars
# 
for each in kinds
    # 
    # 
    # create grammar!
    # 
    # 
    grammar = Grammar.new(
        name: each[:grammar_name],
        scope_name: each[:scope_name],
        fileTypes: each[:fileTypes],
        version: "",
    )

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
        separator = each[:separator]
        grammar[:separator] = Pattern.new(
            tag_as: "punctuation.definition.entry",
            match: separator,
        )
        grammar[:escape] = Pattern.new(
            match: /""/,
            tag_as: "constant.character.escape",
        )
        generateRow = ->(column_tag:"entity.name.tag", column_number:1, children:[]) do
            PatternRange.new(
                tag_as: "meta.#{column_number}",
                start_pattern: Pattern.new(/(?:\G|\A)/),
                zeroLengthStart?: true,
                end_pattern: Pattern.new(
                    tag_as: "punctuation.definition.entry",
                    match: lookAheadFor(/$/),
                ),
                apply_end_pattern_last: true,
                includes: [
                    # 
                    # only match the first entry
                    # 
                    Pattern.new( # simple pattern
                        match: /(?:\G|\A)[^"#{separator}]*/,
                        tag_as: "string.unquoted #{column_tag} text.csv.column#{column_number}"
                    ).then(
                        grammar[:separator].or(lookAheadFor(/$/)),
                    ),
                    PatternRange.new(
                        tag_as: "string.quoted.double #{column_tag} text.csv.column#{column_number}",
                        zeroLengthStart?: true,
                        start_pattern: Pattern.new(
                            Pattern.new(
                                /(?:\G|\A) */,
                            ).then(
                                tag_as: "punctuation.definition.string",
                                match: '"',
                            )
                        ),
                        apply_end_pattern_last: true,
                        end_pattern: Pattern.new(
                            Pattern.new(
                                tag_as: "punctuation.definition.string",
                                match: '"',
                            ).then(/ */).then(
                            grammar[:separator].or(lookAheadFor(/$/)),
                            )
                        ),
                        includes: [
                            :escape,
                        ],
                    ),
                    # 
                    # subsequent entries
                    # 
                    PatternRange.new(
                        tag_as: "meta.#{column_number}.inner",
                        start_pattern: lookBehindFor(separator).lookAheadToAvoid(/$/),
                        end_pattern: lookAheadFor(/$/),
                        includes: [
                            *children,
                        ],
                    )
                ],
            )
        end
        grammar[:item] = PatternRange.new(
            tag_as: "meta.1",
            start_pattern: Pattern.new(/(?:^|\G|\A)/),
            zeroLengthStart?: true,
            end_pattern: Pattern.new(
                tag_as: "punctuation.definition.entry",
                match: lookAheadFor(/$/),
            ),
            apply_end_pattern_last: true,
            includes: [
                # 
                # only match the first entry in the row
                # 
                Pattern.new( # simple pattern
                    match: /(?:\G|\A)[^"#{separator}]*/,
                    tag_as: "string.unquoted rainbow1 text.csv.column1"
                ).then(
                    grammar[:separator].or(lookAheadFor(/$/)),
                ),
                PatternRange.new(
                    tag_as: "string.quoted.double rainbow1 text.csv.column1",
                    zeroLengthStart?: true,
                    start_pattern: Pattern.new(
                        Pattern.new(
                            /(?:\G|\A) */,
                        ).then(
                            tag_as: "punctuation.definition.string",
                            match: '"',
                        )
                    ),
                    apply_end_pattern_last: true,
                    end_pattern: Pattern.new(
                        Pattern.new(
                            tag_as: "punctuation.definition.string",
                            match: '"',
                        ).then(/ */).then(
                            grammar[:separator].or(lookAheadFor(/$/)),
                        )
                    ),
                    includes: [
                        :escape,
                    ],
                ),
                # 
                # match the rest of the row (head recursion)
                # 
                PatternRange.new(
                    tag_as: "meta.1.inner",
                    start_pattern: lookBehindFor(separator).lookAheadToAvoid(/$/),
                    end_pattern: lookAheadFor(/$/),
                    includes: [
                        generateRow[column_tag:"keyword.rainbow2", column_number:2, children:[
                            generateRow[column_tag:"entity.name.function.rainbow3", column_number:3, children:[
                                generateRow[column_tag:"comment.rainbow4", column_number:4, children:[
                                    generateRow[column_tag:"string.rainbow5", column_number:5, children:[
                                        generateRow[column_tag:"variable.parameter.rainbow6", column_number:6, children:[
                                            generateRow[column_tag:"constant.numeric.rainbow7", column_number:7, children:[
                                                generateRow[column_tag:"entity.name.type.rainbow8", column_number:8, children:[
                                                    generateRow[column_tag:"markup.bold.rainbow9", column_number:9, children:[
                                                        generateRow[column_tag:"invalid.rainbow10", column_number:10, children:[
                                                            :item,
                                                        ]]
                                                    ]]
                                                ]]
                                            ]]
                                        ]]
                                    ]]
                                ]]
                            ]]
                        ]]
                    ],
                )
            ],
        )
    #
    # Save
    #
    grammar.save_to(
        syntax_name: each[:file_name],
        syntax_dir: "./autogenerated",
        tag_dir: "./autogenerated",
    )
end