--_AUTO_RELOAD_DEBUG = function ()
    --print('reload')
--end

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

    for pos, patternLine in song.pattern_iterator:lines_in_track(trackNumber) do
        if not patternLine.is_empty then
            for col, note in ipairs(patternLine.note_columns) do
                if not columns[col] then
                    columns[col] = {}
                end
                local ncol = table.getn(columns[col]) 
                -- if it is a note or a note off
                if note.note_value < 121 then
                    if ncol == 0 and note.note_value < 120 then
                        table.insert(columns[col], {pos.line, copyNote(note)})
                    elseif ncol > 0 then
                        -- It's a note off
                        if note.note_value == 120 then
                            table.insert(columns[col], {pos.line, copyNote(note)})
                            table.insert(blocks, columns[col])
                            columns[col] = {}
                        else
                            table.insert(columns[col], {pos.line - 1})
                            table.insert(blocks, columns[col])
                            columns[col] = {{pos.line, copyNote(note)}}
                        end
                    end
                elseif ncol > 0 then
                    table.insert(columns[col], {pos.line, copyNote(note)})
                end
                note:clear()
            end
        end
        -- Last pattern line: sort and insert notes in the pattern
        if pos.line == patterns[pos.pattern].number_of_lines then
            local pattern = patterns[pos.pattern]

            for i, block in pairs(columns) do
                if block[1] then
                    table.insert(block, {pattern.number_of_lines})
                    table.insert(blocks, block)
                end
                columns = {}
            end
            table.sort(blocks, cmpNoteTable)

            local lastLine = -1
            local columnIndex = 1
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
                local lines = pattern.tracks[trackNumber].lines
                for i, noteValue in ipairs(block) do
                    local note = lines[noteValue[1]].note_columns[columnIndex]
                    if noteValue[2] then
                        note.note_value       = noteValue[2][1]
                        note.instrument_value = noteValue[2][2]
                        note.volume_value     = noteValue[2][3]
                        note.panning_value    = noteValue[2][4]
                        note.delay_value      = noteValue[2][5]
                    end
                end
            end
            blocks = {}
        end
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
