function cmpNoteTable(a, b)
    if a[1][1] ~= b[1][1] then
        return a[1][1] < b[1][1]
    end
    return a[1][2][1] < b[1][2][1]
end
 
function copyNote(note)
    return {
        note.note_value,
        note.instrument_value,
        note.volume_value,
        note.panning_value,   
        note.delay_value     
    }
end

function sortNotesInTrack(trackNumber)
    local columns = {}
    local blocks = {}
    local song = renoise.song()
    local patterns = song.patterns
    local maxColumns = 1

    local start = os.clock()
    renoise.app():show_status('Order notes...')

    for curPattern = 1, #patterns do
        local patternTrack = patterns[curPattern].tracks[trackNumber]
        local lines = patternTrack.lines
        local line = 1
        local number_of_lines = #lines
        local patternLine

        repeat
            patternLine = lines[line]

            if not patternLine.is_empty then
                local note_columns = patternLine.note_columns 
                for col, note in ipairs(note_columns) do
                    if not note.is_empty then
                        if not columns[col] then
                            columns[col] = {}
                        end
                        local ncol = table.getn(columns[col]) 
                        local note_value = note.note_value
                        -- if it is a note or a note off
                        if note_value < 121 then
                            -- Start a new note block
                            if ncol == 0 and note_value < 120 then
                                table.insert(columns[col], {line, copyNote(note)})
                            elseif ncol > 0 then
                                -- End the current block
                                if note_value == 120 then
                                    table.insert(columns[col], {line, copyNote(note)})
                                    table.insert(blocks, columns[col])
                                    columns[col] = {}
                                -- End the current block and start a new one
                                else
                                    table.insert(columns[col], {line - 1})
                                    table.insert(blocks, columns[col])
                                    columns[col] = {{line, copyNote(note)}}
                                end
                            end
                        -- Collect note data
                        elseif ncol > 0 then
                            table.insert(columns[col], {line, copyNote(note)})
                        end
                        note:clear()
                    end
                end
            end
            line = line + 1
        until line > number_of_lines

        for i, block in pairs(columns) do
            if block[1] then
                table.insert(block, {#lines})
                table.insert(blocks, block)
            end
            columns = {}
        end

        table.sort(blocks, cmpNoteTable)

        local lastLine = -1
        local columnIndex = 1
        -- TODO Keep track of previous notes for sorting
        for i, block in ipairs(blocks) do
            if lastLine == block[1][1] then     
                columnIndex = columnIndex + 1
                if columnIndex > maxColumns then
                    maxColumns = columnIndex
                end
            else
                columnIndex = 1
                lastLine = block[1][1]
            end
            for i = block[1][1], block[table.getn(block)][1] do
                lines[i].note_columns[columnIndex]:clear()
            end
            for i, noteValue in ipairs(block) do
                if noteValue[2] then
                    local note, value = lines[noteValue[1]].note_columns[columnIndex], noteValue[2]
                    note.note_value       = value[1]
                    note.instrument_value = value[2]
                    note.volume_value     = value[3]
                    note.panning_value    = value[4]
                    note.delay_value      = value[5]
                end
            end
        end
        blocks = {}
    end

    song.tracks[trackNumber].visible_note_columns = maxColumns
    renoise.app():show_status(string.format('Order notes took %.2f seconds', os.clock() - start))
end

renoise.tool():add_keybinding {
    name = "Pattern Editor:Pattern Operations:Order Notes",
    invoke = function ()
        sortNotesInTrack(renoise.song().selected_track_index)
    end
}
