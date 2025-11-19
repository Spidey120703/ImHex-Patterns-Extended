#pragma description MPEG-4 Part 14 digital multimedia container (M4A, M4V, M4S)

#pragma endian big

#pragma MIME audio/mp4
#pragma MIME video/mp4
#pragma MIME application/mp4
#pragma MIME audio/x-m4a
#pragma MIME video/x-m4v
#pragma MIME video/iso.segment

import std.io;
import std.mem;
import std.string;

fn to_string(auto var) {
    return str(var);
};

fn format_string(auto string) {
    return string.value;
};

fn format_fixed32(auto fp32) {
    return fp32.integer + fp32.fraction / 65536.0;
};

fn format_fixed16(auto fp16) {
    return fp16.integer + fp16.fraction / 256.0;
};

struct FixedPoint16 {
    u8 integer;
    u8 fraction;
} [[format("format_fixed16")]];

struct FixedPoint32 {
    u16 integer;
    u16 fraction;
} [[format("format_fixed32")]];

struct string {
    char value[std::mem::find_sequence_in_range(0, $, std::mem::size(), 0x00) - $];
} [[sealed, format("format_string")]];

struct BaseBox {
    u64 boxSize = 0;
    u64 startOffset = $;
    u64 endOffset = 0;

    u32 size;
    char type[4];

    // Calculate the size of the current box
    // 1. If the size is equal to 1 -> the box size is equal to 'largeSize' attribute.
    // 2. If the size is equal to 0 -> The box extends to the end of the file.
    // 3. Otherwise, size is equaly to the 'size' attribute.
    if (this.size == 1) {
        u64 largeSize;
        boxSize = largeSize;
        endOffset = startOffset + boxSize;
    } else if (this.size == 0) {
        boxSize = std::mem::size() - startOffset;
        endOffset = std::mem::size();
    } else {
        boxSize = size;
        endOffset = startOffset + boxSize;
    }

    if (this.type == "uuid") {
        char usertype[16];
    }
};

struct FullBox : BaseBox {
    u8 version;
    u24 flags;
};

struct UnknownBox : BaseBox {
    u8 unk[while($ != endOffset)];
};

using brand = u32 [[format("to_string")]];
struct FileTypeBox : BaseBox {
    brand major_brand;
    u32 minor_version;
    brand compatible_brands[(endOffset - $) / sizeof(brand)];
};

struct MovieHeaderBox : FullBox {
    if (this.version == 1) {
        u64 creation_time;
        u64 modification_time;
        u32 timescale;
        u64 duration;
    } else {  // version == 0
        u32 creation_time;
        u32 modification_time;
        u32 timescale;
        u32 duration;
    }
    FixedPoint32 rate;
    FixedPoint16 volume;
    u8 reserved[10] [[sealed]];
    u32 matrix[9];
    u32 preview_time;
    u32 preview_duration;
    u32 poster_time;
    u32 selection_time;
    u32 selection_duration;
    u32 current_time;
    u32 next_track_id;
};

struct TrackHeaderBox : FullBox {
    if (this.version == 1) {
        u64 creation_time;
        u64 modification_time;
        u32 track_id;
        u32 reserved;
        u64 duration;
    } else {  // version == 0
        u32 creation_time;
        u32 modification_time;
        u32 track_id;
        u32 reserved;
        u32 duration;
    }
    u32 reserved_2[2] [[sealed]];
    s16 layer;
    s16 alternate_group;
    s16 volume;
    u16 reserved_3;
    s32 matrix[9];
    FixedPoint32 width;
    FixedPoint32 height;
};

struct DataEntryBox : FullBox {
    if (std::string::contains(this.type, "url")) {
        string location;
    } else if (std::string::contains(this.type, "urn")) {
        string name;
        string location;
    } else {
        std::error("Invalid DataEntryBox");
    }
};

struct DataReferenceBox : FullBox {
    u32 entry_count;
    DataEntryBox data_entries[this.entry_count];
};

struct SubDataInformationBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("dref"): DataReferenceBox box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("DataInformationBox({})", box.type))]];

struct DataInformationBox : BaseBox {
    SubDataInformationBox box[while($ < endOffset)] [[inline]];
};

struct HandlerBox : FullBox {
    u32 component_type;
    char handler_type[4];
    u32 reserved[3];
    char name[endOffset - $];
};

struct VideoMediaHeaderBox : FullBox {
    u16 graphicsmode;
    u16 opcolor[3];
};

struct Avc1Box : BaseBox {
    u48 reserved;
    u16 data_reference_index;
    u16 version;
    u16 revision_level;
    u32 max_packet_size;
    if (this.version == 0 || this.version == 1) {
        u32 temporal_quality;
        u32 spatial_quality;
        u16 width;
        u16 height;
        FixedPoint32 horizontal_resolution;
        FixedPoint32 vertical_resolution;
        u32 data_size;
        u16 frame_count;
        char compressor_name[32];
        u16 depth;
        s16 color_table_id;
    }
    u8 unk[while($ != endOffset)];
};

struct Mp4aBox : BaseBox {
    u48 reserved;
    u16 data_reference_index;
    u16 version;
    u16 revision_level;
    u32 max_packet_size;
    if (this.version == 0) {
        u16 num_audio_channels;
        u16 sample_size;
        u16 compression_id;
        u16 packet_size;
        FixedPoint32 sample_rate;
    }
    u8 unk[while($ != endOffset)];
};

struct SubSampleDescriptionBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("mp4a"): Mp4aBox box [[inline]];
        ("avc1"): Avc1Box box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("SubSampleDescriptionBox({})", box.type))]];

struct SampleDescriptionBox : FullBox {
        u32 entry_count;
        SubSampleDescriptionBox box[while($ < endOffset)] [[inline]];
};

struct SampleTimeToSampleEntry {
    u32 sample_count;
    u32 sample_delta;
};

struct SampleTimeToSampleBox: FullBox {
    u32 entry_count;
    SampleTimeToSampleEntry entry_list[this.entry_count];
    u8 unk[while($ != endOffset)];
};

struct SampleToChunkEntry {
    u32 first_chunk;
    u32 samples_per_chunk;
    u32 sample_description_index;
};

struct SampleToChunkBox: FullBox {
    u32 entry_count;
    SampleToChunkEntry entry_list[this.entry_count];
    u8 unk[while($ != endOffset)];
};

struct ChunkOffsetBox: FullBox {
    u32 entry_count;
    u32 chunk_offset[this.entry_count];
    u8 unk[while($ != endOffset)];
};

struct SyncSampleBox: FullBox {
    u32 entry_count;
    u32 sample_number[this.entry_count];
    u8 unk[while($ != endOffset)];
};

struct CompositionOffsetEntryV0 {
    u32 sample_count;
    u32 sample_offset;
};

struct CompositionOffsetEntryV1 {
    u32 sample_count;
    s32 sample_offset;
};

struct CompositionOffsetBox: FullBox {
    u32 entry_count;
    if(this.version == 0) {
        CompositionOffsetEntryV0 entry_list[this.entry_count];
    }
    else if (this.version == 1) {
        CompositionOffsetEntryV1 entry_list[this.entry_count];
    }
};

struct SampleSizeBox: FullBox {
    u32 sample_size;
    u32 sample_count;
    if(this.sample_size==0) {
        u32 entry_size[this.sample_count];
    }
};

struct SubSampleBoxTable {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("stsd"): SampleDescriptionBox box [[inline]];
        ("stts"): SampleTimeToSampleBox box [[inline]];
        ("stsc"): SampleToChunkBox box [[inline]];
        ("stco"): ChunkOffsetBox box [[inline]];
        ("stss"): SyncSampleBox box [[inline]];
        ("ctts"): CompositionOffsetBox box [[inline]];
        ("stsz"): SampleSizeBox box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("SubSampleBoxTable({})", box.type))]];

struct SampleBoxTable : BaseBox {
    SubSampleBoxTable box[while($ < endOffset)] [[inline]];
};

struct SubMediaInformationBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("vmhd"): VideoMediaHeaderBox box [[inline]];
        ("hdlr"): HandlerBox box [[inline]];
        ("dinf"): DataInformationBox box [[inline]];
        ("stbl"): SampleBoxTable box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("MediaInformationBox({})", box.type))]];

struct MediaInformationBox : BaseBox {
    SubMediaInformationBox box[while($ < endOffset)] [[inline]];
};

struct MediaHeaderBox : FullBox {
    if (this.version == 1) {
        u64 creation_time;
        u64 modification_time;
        u32 timescale;
        u64 duration;
    } else { // version==0
        u32 creation_time;
        u32 modification_time;
        u32 timescale;
        u32 duration;
    }
    u16 language [[comment("ISO-639-2/T language code")]];
    u16 quality;
};

struct SubMediaBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("mdhd"): MediaHeaderBox box [[inline]];
        ("hdlr"): HandlerBox box [[inline]];
        ("minf"): MediaInformationBox box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("MediaBox({})", box.type))]];

struct MediaBox : BaseBox {
    SubMediaBox box[while($ < endOffset)] [[inline]];
};

struct EditListEntry64 {
    u64 segment_duration;
    s64 media_time;
    s16 media_rate_integer;
    s16 media_rate_fraction;
};

struct EditListEntry32 {
    u32 segment_duration;
    s32 media_time;
    s16 media_rate_integer;
    s16 media_rate_fraction;
};

struct EditListBox : FullBox {
    u32 entry_count;
    if (this.version == 1) {
        EditListEntry64 entry_list[this.entry_count];
    } else {  // version 0
        EditListEntry32 entry_list[this.entry_count];
    }
};

struct SubEditBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("elst"): EditListBox box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("EditBox({})", box.type))]];

struct EditBox : BaseBox {
    SubEditBox box[while($ < endOffset)] [[inline]];
};

struct SubTrackBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("mdia"): MediaBox box [[inline]];
        ("edts"): EditBox box [[inline]];
        ("tkhd"): TrackHeaderBox box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("TrackBox({})", box.type))]];

struct TrackBox : BaseBox {
    SubTrackBox box[while($ < endOffset)] [[inline]];
};

// Extended: Start - 'moov' / 'udta' box
struct MovieUserDataHandlerBox : FullBox {
    u32 component_type;
    char handler_type[4];
    char name[endOffset - $];
};

// Reference: https://developer.apple.com/documentation/quicktime-file-format/well-known_types
enum ItemDataType : u32 {
    Reserved = 0,
    UTF8 = 1,
    UTF16 = 2,
    SJIS = 3,
    UTF8_Sort = 4,
    UTF16_Sort = 5,
    JPEG = 13,
    PNG = 14,
    Int = 21,
    Uint = 22,
    Float32 = 23,
    Float64 = 24,
    BMP = 27,
    QT_Metadata_Atom = 28,
    Int8 = 65,
    Int16 = 66,
    Int32 = 67,
    PointF32 = 70,
    DimensionsF32 = 71,
    RectF32 = 72,
    int64 = 74,
    Uint8 = 75,
    Uint16 = 76,
    Uint32 = 77,
    Uint64 = 78,
    AffineTransformF64 = 79,
};

struct PointF32 {
    be float x;
    be float y;
};

struct DimensionsF32 {
    be float width;
    be float height;
};

struct FlattenedRectF32 {
    be float x;
    be float y;
    be float width;
    be float height;
};

struct StructuredRectF32 {
    PointF32 origin;
    DimensionsF32 size;
};

union RectF32 {
    FlattenedRectF32 flattened;
    StructuredRectF32 structured;
};

struct AffineTransformF64 {
    double matrix[9];
};

struct ItemDataBox : BaseBox {
    ItemDataType data_type;
    u32 reserved;

    if (this.data_type == ItemDataType::Reserved) {
        std::mem::Bytes<endOffset - $> data;
    } else if (this.data_type == ItemDataType::UTF8 || this.data_type == ItemDataType::UTF8_Sort) {
        char data[endOffset - $];
    } else if (this.data_type == ItemDataType::UTF16 || this.data_type == ItemDataType::UTF16_Sort) {
        char16 data[(endOffset - $) >> 1];
    } else if (this.data_type == ItemDataType::SJIS) {
        char16 data[(endOffset - $) >> 1];
    } else if (this.data_type == ItemDataType::JPEG || this.data_type == ItemDataType::PNG || this.data_type == ItemDataType::BMP) {
        std::mem::Bytes<endOffset - $> data;
    } else if (this.data_type == ItemDataType::Int) {
        match (endOffset - $) {
            (1): be s8 data;
            (2): be s16 data;
            (3): be s24 data;
            (4): be s32 data;
            (6): be s48 data;
            (8): be s64 data;
            (12): be s96 data;
            (16): be s128 data;
            (_): std::mem::Bytes<endOffset - $> data;
        }
    } else if (this.data_type == ItemDataType::Uint) {
        match (endOffset - $) {
            (1): be u8 data;
            (2): be u16 data;
            (3): be u24 data;
            (4): be u32 data;
            (6): be u48 data;
            (8): be u64 data;
            (12): be u96 data;
            (16): be u128 data;
            (_): std::mem::Bytes<endOffset - $> data;
        }
    } else if (this.data_type == ItemDataType::Int8 || this.data_type == ItemDataType::Uint8) {
        if (endOffset - $ != 1) {
            std::mem::Bytes<endOffset - $> data;
        } else {
            match (this.data_type) {
                (ItemDataType::Int8): be s8 data;
                (ItemDataType::Uint8): be u8 data;
            }
        }
    } else if (this.data_type == ItemDataType::Int16 || this.data_type == ItemDataType::Uint16) {
        if (endOffset - $ != 2) {
            std::mem::Bytes<endOffset - $> data;
        } else {
            match (this.data_type) {
                (ItemDataType::Int16): be s16 data;
                (ItemDataType::Uint16): be u16 data;
            }
        }
    } else if (this.data_type == ItemDataType::Int32 || this.data_type == ItemDataType::Uint32) {
        if (endOffset - $ != 4) {
            std::mem::Bytes<endOffset - $> data;
        } else {
            match (this.data_type) {
                (ItemDataType::Int32): be s32 data;
                (ItemDataType::Uint32): be u32 data;
            }
        }
    } else if (this.data_type == ItemDataType::Int64 || this.data_type == ItemDataType::Uint64) {
        if (endOffset - $ != 8) {
            std::mem::Bytes<endOffset - $> data;
        } else {
            match (this.data_type) {
                (ItemDataType::Int64): be s64 data;
                (ItemDataType::Uint64): be u64 data;
            }
        }
    } else if (this.data_type == ItemDataType::Float32) {
        if (endOffset - $ != 4) {
            std::mem::Bytes<endOffset - $> data;
        } else {
            be float data;
        }
    } else if (this.data_type == ItemDataType::Float64) {
        if (endOffset - $ != 8) {
            std::mem::Bytes<endOffset - $> data;
        } else {
            be double data;
        }
    } else if (this.data_type == ItemDataType::QT_metadata_atom) {
        std::mem::Bytes<endOffset - $> data;
    } else if (this.data_type == ItemDataType::PointF32) {
        if (endOffset - $ != sizeof(PointF32)) {
            std::mem::Bytes<endOffset - $> data;
        } else {
            PointF32 data;
        }
    } else if (this.data_type == ItemDataType::DimensionsF32) {
        if (endOffset - $ != sizeof(DimensionsF32)) {
            std::mem::Bytes<endOffset - $> data;
        } else {
            DimensionsF32 data;
        }
    } else if (this.data_type == ItemDataType::RectF32) {
        if (endOffset - $ != sizeof(RectF32)) {
            std::mem::Bytes<endOffset - $> data;
        } else {
            RectF32 data;
        }
    } else if (this.data_type == ItemDataType::AffineTransformF64) {
        if (endOffset - $ != sizeof(AffineTransformF64)) {
            std::mem::Bytes<endOffset - $> data;
        } else {
            AffineTransformF64 data;
        }
    } else {
        std::mem::Bytes<endOffset - $> data;
    }
};

struct ITunesItemDataBox : FullBox {
    char data[endOffset - $];
};

struct SubITunesItemBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("mean"): ITunesItemDataBox box [[inline]];
        ("name"): ITunesItemDataBox box [[inline]];
        ("data"): ItemDataBox box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("ITunesItemDataBox({})", box.type))]];

struct ITunesItemBox : BaseBox {
    SubITunesItemBox box[while($ < endOffset)] [[inline]];
};

struct SubItemBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("data"): ItemDataBox box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("ItemBox({})", box.type))]];

struct ItemBox : BaseBox {
    SubItemBox box[while($ < endOffset)] [[inline]];
};

struct SubItemListBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("----"): ITunesItemBox box [[inline]];
        (_): ItemBox box [[inline]];
    }
} [[name(std::format("ItemListBox({})", box.type))]];

struct ItemListBox : BaseBox {
    SubItemListBox box[while($ < endOffset)] [[inline]];
};

struct SubMetaBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("hdlr"): MovieUserDataHandlerBox box [[inline]];
        ("ilst"): ItemListBox box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("MetaBox({})", box.type))]];

struct MetaBox : FullBox {
    SubMetaBox box[while($ < endOffset)] [[inline]];
};

struct SubMovieUserDataBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("meta"): MetaBox box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("MovieUserDataBox({})", box.type))]];

struct MovieUserDataBox : BaseBox {
    SubMovieUserDataBox box[while($ < endOffset)] [[inline]];
};
// Extended: End - 'moov' / 'udta' box

// Extended: Start - 'moov' / 'mvex' box
struct TrackExtendsBox : FullBox {
    u32 track_ID;
    u32 default_sample_description_index;
    u32 default_sample_duration;
    u32 default_sample_size;
    u32 default_sample_flags;
};

struct SubMovieExtendsBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("trex"): TrackExtendsBox box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("MovieExtendsBox({})", box.type))]];

struct MovieExtendsBox : BaseBox {
    SubMovieExtendsBox box[while($ < endOffset)] [[inline]];
};

struct SubMovieBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("mvhd"): MovieHeaderBox box [[inline]];
        ("trak"): TrackBox box [[inline]];
        ("udta"): MovieUserDataBox box [[inline]]; // Extended: Add 'udat' box
        ("mvex"): MovieExtendsBox box [[inline]]; // Extended: Add 'mvex' box
        (_): UnknownBox box [[inline]];
        // TODO: Add "iods" box
    }
} [[name(std::format("MovieBox({})", box.type))]];

struct MovieBox : BaseBox {
    SubMovieBox box[while($ < endOffset)] [[inline]];
};

struct MediaDataBox : BaseBox {
    std::mem::Bytes<boxSize - sizeof(size) - sizeof(type)> data;
};


struct MovieFragmentHeaderBox : FullBox {
    u32 sequence_number;
};

struct TrackFragmentHeaderBox : FullBox {
    u32 track_id;
    if (this.flags & 0x000001) {
        u64 base_data_offset;
    }
    if (this.flags & 0x000002) {
        u32 sample_description_index;
    }
    if (this.flags & 0x000008) {
        u32 default_sample_duration;
    }
    if (this.flags & 0x000010) {
        u32 default_sample_size;
    }
    if (this.flags & 0x000020) {    
        u32 default_sample_flags;
    }
};

struct TrackFragmentBaseMediaDecodeTimeBox : FullBox {
    if (this.version == 1) {
        u64 base_media_decode_time;
    } else { // if (this.version == 0)
        u32 base_media_decode_time;
    }
};

struct SubsampleBoxEntry {
    u16 bytes_of_clear_data;
    u32 bytes_of_protected_data;
};

struct SubsampleBoxEntryV1 {
    u16 multi_subindex;
    u16 bytes_of_clear_data;
    u32 bytes_of_protected_data;
};

struct SampleEncryptionEntryV1 {
    u16 multi_iv_count;
    u16 multi_subindex_iv[multi_iv_count];
    u16 subsample_count;
    SubsampleBoxEntryV1 subsample_entries[subsample_count];
};

struct SampleEncryptionEntryV2 {
    // u16 initialization_vector_size;
    u16 subsample_count;
    SubsampleBoxEntry subsample_entries[subsample_count];
};

struct SampleEncryptionBox : FullBox {
    u32 sample_count;
    if (this.version == 0) {
        SampleEncryptionEntryV2 sample_entries[sample_count];
    } else if (this.version == 1) {
        SampleEncryptionEntryV1 sample_entries[sample_count];
    } else if (this.version == 2) {
        SampleEncryptionEntryV2 sample_entries[sample_count];
    }
    u8 unk[while($ != endOffset)];
};

struct TrackRunSampleEntry {
    // u32 sample_duration;
    // u32 sample_size;
    // u32 sample_flags;
    // if (this.version == 0) {
    //     u32 sample_composition_time_offset;
    // } else { // if (this.version == 1)
    //     s32 sample_composition_time_offset;
    // }

    // TODO: ImHex does not support context-aware fields yet.
};

struct TrackRunBox : FullBox {
    u32 sample_count;
    if (this.flags & 0x000001) {
        u32 data_offset;
    }
    if (this.flags & 0x000004) {
        u32 first_sample_flags;
    }
    // TrackRunSampleEntry sample_entries[this.sample_count];
    u8 unk[while($ != endOffset)];
};

struct SubTrackFragmentBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("tfhd"): TrackFragmentHeaderBox box [[inline]];
        ("tfdt"): TrackFragmentBaseMediaDecodeTimeBox box [[inline]];
        ("senc"): SampleEncryptionBox box [[inline]];
        ("trun"): TrackRunBox box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("TrackFragmentBox({})", box.type))]];

struct TrackFragmentBox : BaseBox {
    SubTrackFragmentBox box[while($ < endOffset)] [[inline]];
};

struct SubMovieFragmentBox {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("mfhd"): MovieFragmentHeaderBox box [[inline]];
        ("traf"): TrackFragmentBox box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("MovieFragmentBox({})", box.type))]];

struct MovieFragmentBox : BaseBox {
    SubMovieFragmentBox box[while($ < endOffset)] [[inline]];
};


struct Box {
    u32 type = std::mem::read_unsigned($ + 4, 4, std::mem::Endian::Big);

    match (str(type)) {
        ("ftyp"): FileTypeBox box [[inline]];
        ("moov"): MovieBox box [[inline]];
        ("moof"): MovieFragmentBox box [[inline]];
        ("mdat"): MediaDataBox box [[inline]];
        (_): UnknownBox box [[inline]];
    }
} [[name(std::format("Box({})", box.type))]];

Box m4a[while(!std::mem::eof())] @ 0x0;
