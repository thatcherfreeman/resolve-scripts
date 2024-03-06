--[[
Looks up the file corresponding to the current DNG clip, then spits out a DCTL that will
transform it to the specified color space.
--]]

function print_table(t, indentation)
    if indentation == nil then
        indentation = 0
    end
    local outer_prefix = string.rep("    ", indentation)
    local inner_prefix = string.rep("    ", indentation + 1)
    print(outer_prefix, "{")
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(inner_prefix, k, ": ")
            print_table(v, indentation + 1)
        elseif type(v) == "string" then
            print(inner_prefix, k, string.format([[: "%s"]], v))
        else
            print(inner_prefix, k, ": ", v)
        end
    end
    print(outer_prefix, "}")
end

function runCmd(cmd)
    local fileHandle = assert(io.popen(cmd, 'r'))
    local out = assert(fileHandle:read('*a'))
    fileHandle:close()
    return out
end

function string:endswith(suffix)
    return self:sub(-#suffix) == suffix
end

function read_csv(csv)
    -- Assume csv is a string, whose first line is comma separated column names
    -- Second row is values.
    local rows = {}
    for row in csv:gmatch("[^\n]+") do
        table.insert(rows, row)
    end
    local col_names = rows[1]
    local values = rows[2]
    local parsed_values = {}
    local parsed_col_names = {}
    for col_name in col_names:gmatch("[^,]+") do
        table.insert(parsed_col_names, col_name)
    end
    for value in values:gmatch("[^,]+") do
        local table_value = {}
        -- Read numerical data.
        if value:match("^[%d%-]") ~= nil then
            for f in value:gmatch("%-?%d+%.?%d*") do
                table.insert(table_value, tonumber(f))
            end
        end
        if #table_value >= 1 then
            table.insert(parsed_values, table_value)
        else
            table.insert(parsed_values, value)
        end
    end
    local output = {}
    for i = 1, #parsed_col_names do
        output[parsed_col_names[i]] = parsed_values[i]
    end
    return output
end

function cleanup_exif_tags(exif_tags)
    local output = exif_tags
    for k,v in pairs(exif_tags) do
        output[k] = v
    end
    local num_illuminants = 0
    if output['AnalogBalance'] == nil then
        output['AnalogBalance'] = {1.0, 1.0, 1.0}
    end
    if output['CalibrationIlluminant1'] ~= nil then
        num_illuminants = num_illuminants + 1
    end
    if output['CalibrationIlluminant2'] ~= nil then
        num_illuminants = num_illuminants + 1
    end

    if num_illuminants >= 1 and output['CameraCalibration1'] == nil then
        output['CameraCalibration1'] = diagonal({1.0, 1.0, 1.0})
    end
    if num_illuminants >= 2 and output['CameraCalibration2'] == nil then
        output['CameraCalibration2'] = diagonal({1.0, 1.0, 1.0})
    end
    return output
end

--
-- Linear algebra functions
--

function lerp(a,b,c)
    return (((b) - (a)) * (c) + (a))
end

function diagonal(vec)
    assert(type(vec) == "table" and #vec == 3, "diagonal() called on vec with incorrect size")
    local output = {
        vec[1], 0, 0,
        0, vec[2], 0,
        0, 0, vec[3]
    }
    return output
end

function inverse(mat)
    assert(type(mat) == "table" and #mat == 9, "inverse() called on matrix with incorrect size")
    local out = {}
    local det = mat[1] * (mat[5] * mat[9] - mat[6] * mat[8]) -
                mat[2] * (mat[4] * mat[9] - mat[6] * mat[7]) +
                mat[3] * (mat[4] * mat[8] - mat[5] * mat[7])
    out[1] = (mat[5] * mat[9] - mat[6] * mat[8]) / det
    out[2] = (mat[3] * mat[8] - mat[2] * mat[9]) / det
    out[3] = (mat[2] * mat[6] - mat[3] * mat[5]) / det
    out[4] = (mat[6] * mat[7] - mat[4] * mat[9]) / det
    out[5] = (mat[1] * mat[9] - mat[3] * mat[7]) / det
    out[6] = (mat[3] * mat[4] - mat[1] * mat[6]) / det
    out[7] = (mat[4] * mat[8] - mat[5] * mat[7]) / det
    out[8] = (mat[2] * mat[7] - mat[1] * mat[8]) / det
    out[9] = (mat[1] * mat[5] - mat[2] * mat[4]) / det
    return out
end

function add(mat1, mat2)
    assert(type(mat1) == "table")
    assert(type(mat2) == "table")
    assert(#mat1 == #mat2)

    local out = {}
    for i = 1, #mat1 do
        out[i] = mat1[i] + mat2[i]
    end
    return out
end

function scale(mat, s)
    assert(type(mat) == "table" and type(s) == "number")
    local out = {}
    for i = 1, #mat do
        out[i] = s * mat[i]
    end
    return out
end

function _mv_33_3(m, v)
    assert(type(m) == "table" and #m == 9)
    assert(type(v) == "table" and #v == 3)
    local out = {}
    out[1] = m[1] * v[1] + m[2] * v[2] + m[3] * v[3]
    out[2] = m[4] * v[1] + m[5] * v[2] + m[6] * v[3]
    out[3] = m[7] * v[1] + m[8] * v[2] + m[9] * v[3]
    return out
end


function _mm_33_33(m1, m2)
    assert(type(m1) == "table" and #m1 == 9)
    assert(type(m2) == "table" and #m2 == 9)
    local out = {}
    out[1] = m1[1] * m2[1] + m1[2] * m2[4] + m1[3] * m2[7]
    out[2] = m1[1] * m2[2] + m1[2] * m2[5] + m1[3] * m2[8]
    out[3] = m1[1] * m2[3] + m1[2] * m2[6] + m1[3] * m2[9]
    out[4] = m1[4] * m2[1] + m1[5] * m2[4] + m1[6] * m2[7]
    out[5] = m1[4] * m2[2] + m1[5] * m2[5] + m1[6] * m2[8]
    out[6] = m1[4] * m2[3] + m1[5] * m2[6] + m1[6] * m2[9]
    out[7] = m1[7] * m2[1] + m1[8] * m2[4] + m1[9] * m2[7]
    out[8] = m1[7] * m2[2] + m1[8] * m2[5] + m1[9] * m2[8]
    out[9] = m1[7] * m2[3] + m1[8] * m2[6] + m1[9] * m2[9]
    return out
end

function multiply(mat1, mat2)
    assert(type(mat1) == "table" and #mat1 == 9)
    assert(type(mat2) == "table" and (#mat2 == 9 or #mat2 == 3))
    local out = {}
    if #mat2 == 3 then
        out = _mv_33_3(mat1, mat2)
    elseif #mat2 == 9 then
        out = _mm_33_33(mat1, mat2)
    else
        assert(false, string.format("Unexpected mat2 matrix dimension: %d", #mat2))
    end
    return out
end

--
-- Color Functions
--

D50_XY = {0.34567, 0.35850}
D65_XY = {0.3127, 0.3290}

ACES_AP0_PRIMARIES = {
    red = {0.7347, 0.2653},
    green = {0.0, 1.0},
    blue = {0.0001, -0.0770},
    white = {0.32168, 0.33767},
}

DWG_PRIMARIES = {
    red = {0.800, 0.3130},
    green = {0.1682, 0.9877},
    blue = {0.0790, -0.1155},
    white = D65_XY,
}

function xy_to_xyY(xy)
    assert(type(xy) == "table" and #xy == 2)
    local out = {xy[1], xy[2], 1.0}
    return out
end

function xyY_to_xy(xyY)
    assert(type(xyY) == "table" and #xyY == 3)
    local out = {xyY[1], xyY[2]}
    return out
end

function xyY_to_XYZ(xyY)
    assert(type(xyY) == "table" and #xyY == 3)
    local out = {}
    out[1] = xyY[1] * xyY[3] / xyY[2]
    out[2] = xyY[3]
    out[3] = (1.0 - xyY[1] - xyY[2]) * xyY[3] / xyY[2]
    return out
end

function XYZ_to_xyY(XYZ)
    assert(type(XYZ) == "table" and #XYZ == 3)
    local out = {}
    local sum = XYZ[1] + XYZ[2] + XYZ[3]
    out[1] = XYZ[1] / sum
    out[2] = XYZ[2] / sum
    out[3] = XYZ[2]
    return out
end

function bradford_chromatic_adaptation(source_xy, destination_xy)
    local bradford = {
         0.8951000,  0.2664000, -0.1614000,
        -0.7502000,  1.7135000,  0.0367000,
         0.0389000, -0.0685000,  1.0296000
    }
    local source_XYZ = xyY_to_XYZ(xy_to_xyY(source_xy))
    local destination_XYZ = xyY_to_XYZ(xy_to_xyY(destination_xy))
    local source_lms = multiply(bradford, source_XYZ)
    local destination_lms = multiply(bradford, destination_XYZ)
    local out = multiply(inverse(bradford), multiply(diagonal({destination_lms[1] / source_lms[1], destination_lms[2] / source_lms[2], destination_lms[3] / source_lms[3]}), bradford))
    return out
end


function get_XYZ_to_rgb_matrix(primaries)
    -- Math taken from brucelindbloom.com
    local red_XYZ = xyY_to_XYZ(xy_to_xyY(primaries.red))
    local green_XYZ = xyY_to_XYZ(xy_to_xyY(primaries.green))
    local blue_XYZ = xyY_to_XYZ(xy_to_xyY(primaries.blue))
    local white_XYZ = xyY_to_XYZ(xy_to_xyY(primaries.white))
    local xyzmat = {red_XYZ[1], green_XYZ[1], blue_XYZ[1], red_XYZ[2], green_XYZ[2], blue_XYZ[2], red_XYZ[3], green_XYZ[3], blue_XYZ[3]}
    local srgb = multiply(inverse(xyzmat), white_XYZ)
    local out = inverse(multiply(xyzmat, diagonal(srgb)))
    return out
end

--
-- Ports of DNG functions
--

function illuminant_to_temperature(illuminant)
    assert(type(illuminant) == "string")
    if illuminant == "Tungsten" or illuminant == "Standard Light A" then
        return 2850.0
    elseif illuminant == "ISO Studio Tungsten" then
        return 3200.0
    elseif illuminant == "D50" then
        return 5000.0
    elseif illuminant == "D55" or illuminant == "Daylight" or illuminant == "Fine Weather" or illuminant == "Flash" or illuminant == "Standard Light B" then
        return 5500.0
    elseif illuminant == "D65" or illuminant == "Standard Light C" or illuminant == "Cloudy Weather" then
        return 6500.0
    elseif illuminant == "D75" or illuminant == "Shade" then
        return 7500.0
    elseif illuminant == "Daylight Fluorescent"	then
        return (5700.0 + 7100.0) * 0.5
    elseif illuminant == "Day White Fluorescent" then
        return (4600.0 + 5500.0) * 0.5
    elseif illuminant == "Cool White Fluorescent" or illuminant == "Fluorescent" then
        return (3800.0 + 4500.0) * 0.5
    elseif illuminant == "White Fluorescent" then
        return (3250.0 + 3800.0) * 0.5
    elseif illuminant == "Warm White Fluorescent" then
        return (2600.0 + 3250.0) * 0.5
    elseif illuminant == "Other" then
        assert(false, "Other illuminant type is not supported.")
        -- return dng_temperature (data.WhiteXY ()).Temperature ();
    end
    assert(false, string.format("Unexpected illuminant type: %s", illuminant))
end

function interpolate_matrix(mat1, mat2, temp1, temp2, interp_temp)
    local factor = ((1.0 / interp_temp) - (1.0 / temp2)) / ((1.0 / temp1) - (1.0 / temp2))
    if factor >= 1.0 then
        return mat1
    elseif factor <= 0.0 then
        return mat2
    end
    return add(scale(mat1, factor), scale(mat2, 1.0 - factor))
end

function xy_to_temperature(xy)
    assert(type(xy) == "table" and #xy == 2)
    local xyz = xyY_to_XYZ(xy_to_xyY(xy))
    -- Adapted from brucelindbloom.com
    local rt = {
        -- reciprocal temperature (K)
            0.0,  10.0e-6,  20.0e-6,  30.0e-6,  40.0e-6,  50.0e-6,
        60.0e-6,  70.0e-6,  80.0e-6,  90.0e-6, 100.0e-6, 125.0e-6,
        150.0e-6, 175.0e-6, 200.0e-6, 225.0e-6, 250.0e-6, 275.0e-6,
        300.0e-6, 325.0e-6, 350.0e-6, 375.0e-6, 400.0e-6, 425.0e-6,
        450.0e-6, 475.0e-6, 500.0e-6, 525.0e-6, 550.0e-6, 575.0e-6,
        600.0e-6
    }

    local uvt = {
        {0.18006, 0.26352, -0.24341},
        {0.18066, 0.26589, -0.25479},
        {0.18133, 0.26846, -0.26876},
        {0.18208, 0.27119, -0.28539},
        {0.18293, 0.27407, -0.30470},
        {0.18388, 0.27709, -0.32675},
        {0.18494, 0.28021, -0.35156},
        {0.18611, 0.28342, -0.37915},
        {0.18740, 0.28668, -0.40955},
        {0.18880, 0.28997, -0.44278},
        {0.19032, 0.29326, -0.47888},
        {0.19462, 0.30141, -0.58204},
        {0.19962, 0.30921, -0.70471},
        {0.20525, 0.31647, -0.84901},
        {0.21142, 0.32312, -1.0182},
        {0.21807, 0.32909, -1.2168},
        {0.22511, 0.33439, -1.4512},
        {0.23247, 0.33904, -1.7298},
        {0.24010, 0.34308, -2.0637},
        {0.24792, 0.34655, -2.4681},	--Note: 0.24792 is a corrected value for the error found in W&S as 0.24702
        {0.25591, 0.34951, -2.9641},
        {0.26400, 0.35200, -3.5814},
        {0.27218, 0.35407, -4.3633},
        {0.28039, 0.35577, -5.3762},
        {0.28863, 0.35714, -6.7262},
        {0.29685, 0.35823, -8.5955},
        {0.30505, 0.35907, -11.324},
        {0.31320, 0.35968, -15.628},
        {0.32129, 0.36011, -23.325},
        {0.32931, 0.36038, -40.770},
        {0.33724, 0.36051, -116.45},
    }

    if (xyz[1] < 1.0e-20) and (xyz[2] < 1.0e-20) and (xyz[3] < 1.0e-20) then
        assert(false, "divide by zero error, non-positive xyz input to XYZtoCCT")
    end
    local us = (4.0 * xyz[1]) / (xyz[1] + 15.0 * xyz[2] + 3.0 * xyz[3])
    local vs = (6.0 * xyz[2]) / (xyz[1] + 15.0 * xyz[2] + 3.0 * xyz[3])
    local dm = 0.0
    local i = 1
    local di
    while i <= 31 do
        di = (vs - uvt[i][2]) - uvt[i][3] * (us - uvt[i][1])
        if (i > 1) and (((di < 0.0) and (dm >= 0.0)) or ((di >= 0.0) and (dm < 0.0))) then
            break  --found lines bounding (us, vs) : i-1 and i
        end
        dm = di
        i = i + 1
    end
    if i == 31 then
        assert(false, "Color temp is too low for input xyz")     --bad XYZ input, color temp would be less than minimum of 1666.7 degrees, or too far towards blue
    end
    di = di / math.sqrt(1.0 + uvt[i    ][3] * uvt[i    ][3])
    dm = dm / math.sqrt(1.0 + uvt[i - 1][3] * uvt[i - 1][3])
    local p = dm / (dm - di)     -- p = interpolation parameter, 0.0 : i-1, 1.0 : i
    local temp = 1.0 / (lerp(rt[i - 1], rt[i], p))
    return temp
end

function get_xyz_to_camera_matrix(white_xy, exif_tags)
    -- white_xy is the white chromaticity coordinates corresponding to AsShotNeutral
    local num_illuminants = 1
    if exif_tags['CalibrationIlluminant1'] ~= nil and exif_tags['CalibrationIlluminant2'] ~= nil and exif_tags['CalibrationIlluminant1'] ~= exif_tags['CalibrationIlluminant2'] then
        num_illuminants = 2
    end
    local camera_matrix, camera_calibration, analog_balance, forward_matrix
    if num_illuminants == 1 then
        camera_matrix = multiply(multiply(diagonal(exif_tags['AnalogBalance']), exif_tags['CameraCalibration1']), exif_tags['ColorMatrix1'])
        -- camera_calibration = exif_tags['CameraCalibration1']
        -- analog_balance = exif_tags['AnalogBalance']
        -- forward_matrix = exif_tags['ForwardMatrix1']
    elseif num_illuminants == 2 then
        local illuminant1_temp = illuminant_to_temperature(exif_tags['CalibrationIlluminant1'])
        local illuminant2_temp = illuminant_to_temperature(exif_tags['CalibrationIlluminant2'])
        local white_temp = xy_to_temperature(white_xy)
        local camera_matrix1 = multiply(multiply(diagonal(exif_tags['AnalogBalance']), exif_tags['CameraCalibration1']), exif_tags['ColorMatrix1'])
        local camera_matrix2 = multiply(multiply(diagonal(exif_tags['AnalogBalance']), exif_tags['CameraCalibration2']), exif_tags['ColorMatrix2'])
        camera_matrix = interpolate_matrix(camera_matrix1, camera_matrix2, illuminant1_temp, illuminant2_temp, white_temp)
        -- camera_calibration = interpolate_matrix(exif_tags['CameraCalibration1'], exif_tags['CameraCalibration2'], illuminant1_temp, illuminant2_temp, white_temp)
        -- forward_matrix = interpolate_matrix(exif_tags['ForwardMatrix1'], exif_tags['ForwardMatrix2'], illuminant1_temp, illuminant2_temp, white_temp)
        -- analog_balance = exif_tags['AnalogBalance']
    else
        assert(false, string.format("num_illuminants is unsupported amount: %d", num_illuminants))
    end
    return camera_matrix
end

function neutral_to_xy(neutral, exif_tags)
    local max_passes = 30
	local last_xy = D50_XY;
	for pass = 1, max_passes do
		local xyz_to_camera = get_xyz_to_camera_matrix(last_xy, exif_tags)
		local next_xy = xyY_to_xy(XYZ_to_xyY(multiply(inverse(xyz_to_camera), neutral)))
		if (math.abs(next_xy[1] - last_xy[1]) +
			math.abs(next_xy[2] - last_xy[2])) < 0.0000001 then
			return next_xy
        end

		-- If we reach the limit without converging, we are most likely
		-- in a two value oscillation. So take the average of the last
		-- two estimates and give up.
		if pass == kMaxPasses then
			next_xy[1] = (last_xy[1] + next_xy[1]) * 0.5;
			next_xy[2] = (last_xy[2] + next_xy[2]) * 0.5;
        end
        last_xy = next_xy;
    end
	return last_xy;
end

local resolve = Resolve()
local projectManager = resolve:GetProjectManager()
local project = projectManager:GetCurrentProject()
local timeline = project:GetCurrentTimeline()
local clip = timeline:GetCurrentVideoItem()
local media_item = clip:GetMediaPoolItem()
local separator = package.config:sub(1,1)
-- print("Metadata:")
-- print_table(media_item:GetMetadata())
-- print("Clip Properties:")
-- print_table(media_item:GetClipProperty())

local file_path = media_item:GetClipProperty("File Path")
assert(file_path:endswith(".dng"), "File for current clip needs to end with .dng!")
print("Found file: ", file_path)

file_path = string.gsub(file_path, "(%[(%d+)%-(%d+)%])", "%2")
print("Extracting exif from: ", file_path)

local exiftool_prefix = '/opt/homebrew/bin/'

print(os.getenv('PATH'))
local cmd = string.format([[%sexiftool -csv -s -UniqueCameraModel -ForwardMatrix1 -ForwardMatrix2 -AsShotNeutral -AsShotWhiteXY -ColorMatrix1 -ColorMatrix2 -AnalogBalance -CameraCalibration1 -CameraCalibration2 -CalibrationIlluminant1 -CalibrationIlluminant2 "%s"]], exiftool_prefix, file_path)
print(cmd)
local csv = runCmd(cmd)
local exif_tags = read_csv(csv)
local exif_tags = cleanup_exif_tags(exif_tags)
print("Extracted tags: ")
print_table(exif_tags)

local white_xy
if exif_tags['AsShotNeutral'] ~= nil then
    white_xy = neutral_to_xy(exif_tags['AsShotNeutral'], exif_tags)
elseif exif_tags['AsShotWhiteXY'] ~= nil then
    white_xy = exif_tags['AsShotWhiteXY']
else
    print("Camera doesn't have AsShotNeutral or AsShotWhiteXY tags, assuming D50.")
    white_xy = D50_XY
end
print("White xy coordinates: ")
print_table(white_xy)
local camera_to_pcs = multiply(bradford_chromatic_adaptation(white_xy, D50_XY), inverse(get_xyz_to_camera_matrix(white_xy, exif_tags)))
local camera_to_xyz_d65 = multiply(bradford_chromatic_adaptation(D50_XY, D65_XY), camera_to_pcs)

print("Camera to XYZ D65: ")
print_table(camera_to_xyz_d65)
print("Camera to XYZ D65 with compensation for Resolve default white balance: ")
print_table(multiply(camera_to_xyz_d65, diagonal(exif_tags['AsShotNeutral'])))
