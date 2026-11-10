#include "4DPluginAPI.h"
#include "PrivateTypes.h"
#include "EntryPoints.h"

#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <set>

namespace {
std::map<PA_Unichar*, size_t> strings;
std::map<PA_Handle, size_t> handles;
std::map<PA_Picture, unsigned> pictures;
bool allocatedEmpty = true;
CUTF16String expectedPath, expectedType;

void require(bool condition, const char* message)
{
    if (!condition) {
        std::fprintf(stderr, "ownership regression: %s\n", message);
        std::abort();
    }
}

CUTF16String text(const PA_Unistring& value)
{
    if (!value.fString) {
        require(value.fLength == 0, "null string must be empty");
        return CUTF16String();
    }
    require(strings.count(value.fString), "string owner already disposed");
    require(strings.at(value.fString) == size_t(value.fLength), "exact string length");
    require(value.fString[value.fLength] == 0, "UTF-16 terminator");
    return CUTF16String(value.fString, value.fLength);
}

PA_Unistring makeString(const PA_Unichar* source)
{
    size_t length = 0;
    if (source)
        while (source[length]) ++length;
    PA_Unistring value = {};
    value.fLength = PA_long32(length);
    if (length || allocatedEmpty) {
        value.fString = new PA_Unichar[length + 1]();
        if (length) std::memcpy(value.fString, source, length * sizeof(PA_Unichar));
        strings[value.fString] = length;
    }
    return value;
}

void disposeString(const PA_Unistring& value)
{
    if (!value.fString) return;
    require(strings.erase(value.fString) == 1, "double disposal of transferred path string");
    delete[] value.fString;
}

PA_Picture makePicture()
{
    PA_Picture value = new char;
    pictures[value] = 1;
    return value;
}

void disposePicture(PA_Picture value)
{
    if (!value) return;
    require(pictures.count(value), "picture use after disposal");
    if (--pictures[value] == 0) {
        pictures.erase(value);
        delete static_cast<char*>(value);
    }
}

void clear(PA_Variable* value)
{
    if (value->fType == eVK_Unistring) disposeString(value->uValue.fString);
    if (value->fType == eVK_Picture) disposePicture(value->uValue.fPicture);
    if (value->fType == eVK_ArrayUnicode && value->uValue.fArray.fData) {
        auto elements = reinterpret_cast<PA_Unistring*>(*value->uValue.fArray.fData);
        for (PA_long32 i = 0; i <= value->uValue.fArray.fNbElements; ++i)
            disposeString(elements[i]);
        PA_DisposeHandle(value->uValue.fArray.fData);
    }
    *value = {};
    value->fType = eVK_Undefined;
}

void balanced(const char* label)
{
    if (!strings.empty() || !handles.empty() || !pictures.empty()) {
        std::fprintf(stderr, "%s: strings=%zu handles=%zu pictures=%zu\n",
                     label, strings.size(), handles.size(), pictures.size());
        require(false, "all owned strings, handles and picture refs released");
    }
}

void engine(short selector, EngineBlock* eb)
{
    eb->fError = 0;
    switch (selector) {
        case EX_CREATE_UNISTRING:
            eb->fUniString1 = makeString(reinterpret_cast<PA_Unichar*>(eb->fHandle));
            break;
        case EX_DISPOSE_UNISTRING:
            disposeString(eb->fUniString1);
            break;
        case EX_SET_UNISTRING: {
            PA_Unistring replacement = makeString(reinterpret_cast<PA_Unichar*>(eb->fHandle));
            disposeString(eb->fUniString1);
            eb->fUniString1 = replacement;
            break;
        }
        case EX_CREATE_PICTURE:
            eb->fPicture = makePicture();
            break;
        case EX_DISPOSE_PICTURE:
            disposePicture(eb->fPicture);
            break;
        case EX_DUPLICATE_PICTURE:
            require(pictures.count(eb->fPicture), "retain live borrowed picture");
            require(eb->fParam1 == 0, "wrapper requests retain-only");
            ++pictures[eb->fPicture];
            break;
        case EX_GET_PICTURE_DATA:
            require(pictures.count(eb->fPicture), "read retained picture");
            // No representations. Failed output is deliberately not initialized.
            eb->fError = eER_IncompatibleTypes;
            break;
        case EX_CLEAR_VARIABLE:
            clear(static_cast<PA_Variable*>(eb->fPtr1));
            break;
        case EX_HANDLE_MANAGER: {
            switch (eb->fParam1) {
                case 1: {
                    PA_Handle handle = new char*;
                    *handle = new char[size_t(eb->fParam2)]();
                    handles[handle] = size_t(eb->fParam2);
                    eb->fHandle = handle;
                    break;
                }
                case 2:
                    require(handles.erase(eb->fHandle) == 1, "dispose live handle");
                    delete[] *eb->fHandle;
                    delete eb->fHandle;
                    break;
                case 3: {
                    require(handles.count(eb->fHandle), "resize live handle");
                    size_t size = size_t(eb->fParam2);
                    char* replacement = new char[size]();
                    std::memcpy(replacement, *eb->fHandle,
                                std::min(size, handles.at(eb->fHandle)));
                    delete[] *eb->fHandle;
                    *eb->fHandle = replacement;
                    handles[eb->fHandle] = size;
                    break;
                }
                case 4:
                    eb->fParam2 = handles.at(eb->fHandle);
                    break;
                case 5:
                    require(handles.count(eb->fHandle), "lock live handle");
                    eb->fParam3 = reinterpret_cast<sLONG_PTR>(*eb->fHandle);
                    break;
                case 6:
                    require(handles.count(eb->fHandle), "unlock live handle");
                    break;
                default: require(false, "unexpected handle operation");
            }
            break;
        }
        case EX_CONVERT_CHARSET_TO_CHARSET: {
            require(eb->fParam2 == eVTC_UTF_8 && eb->fParam4 == eVTC_UTF_16,
                    "conversion fixture is UTF-8 to UTF-16");
            CFStringRef converted = CFStringCreateWithBytes(
                kCFAllocatorDefault, static_cast<const UInt8*>(eb->fPtr1),
                eb->fParam1, kCFStringEncodingUTF8, false);
            require(converted != nullptr, "valid synthetic UTF-8 fixture");
            size_t units = size_t(CFStringGetLength(converted));
            size_t bytes = units * sizeof(PA_Unichar);
            require(bytes <= size_t(eb->fParam3), "conversion byte capacity");
            CFStringGetCharacters(converted, CFRangeMake(0, units),
                                  static_cast<UniChar*>(eb->fPtr2));
            if (bytes + sizeof(PA_Unichar) <= size_t(eb->fParam3))
                static_cast<PA_Unichar*>(eb->fPtr2)[units] = 0;
            eb->fParam3 = bytes; // SDK explicitly returns bytes, not UTF-16 units.
            CFRelease(converted);
            break;
        }
        case EX_EXECUTE_COMMAND_BY_ID: {
            auto args = static_cast<PA_Variable**>(eb->fPtr1);
            auto returned = static_cast<PA_Variable*>(eb->fPtr2);
            require(returned->fType == eVK_Undefined, "procedure has no owning result");
            switch (eb->fParam1) {
                case 678:
                    require(text(args[0]->uValue.fString) == expectedPath, "exact file path");
                    require(args[1]->fType == eVK_Picture, "picture output argument");
                    PA_ClearVariable(args[1]);
                    PA_SetPictureVariable(args[1], makePicture());
                    break;
                case 1002:
                    require(text(args[1]->uValue.fString) == expectedType, "exact converted type");
                    require(pictures.count(PA_GetPictureVariable(*args[0])), "conversion input alive");
                    PA_ClearVariable(args[0]);
                    PA_SetPictureVariable(args[0], makePicture());
                    break;
                case 988:
                    require(pictures.count(PA_GetPictureVariable(*args[0])), "transform input alive");
                    PA_ClearVariable(args[0]);
                    PA_SetPictureVariable(args[0], makePicture());
                    break;
                case 457:
                    require(pictures.count(PA_GetPictureVariable(*args[0])), "properties input alive");
                    PA_SetLongintVariable(args[1], 17);
                    PA_SetLongintVariable(args[2], 23);
                    break;
                case 679:
                    require(pictures.count(PA_GetPictureVariable(*args[0])), "thumbnail input alive");
                    PA_ClearVariable(args[1]);
                    PA_SetPictureVariable(args[1], makePicture());
                    break;
                default: require(false, "unexpected command");
            }
            break;
        }
        default:
            std::fprintf(stderr, "unexpected engine selector: %d\n", selector);
            require(false, "unexpected engine boundary");
    }
}

CUTF16String utf16(const char* utf8)
{
    C_TEXT converted;
    converted.setUTF8String(reinterpret_cast<const uint8_t*>(utf8), std::strlen(utf8));
    CUTF16String result;
    converted.copyUTF16String(&result);
    return result;
}

void pictureCase(const std::string& name)
{
    std::vector<PA_Picture> handoffs;
    {
        CPicture picture;
        if (name == "path") {
            for (const char* path : {"", "sample.png", "\xe6\x97\xa5.png", "\xf0\x9f\x98\x80.png"}) {
                expectedPath = utf16(path);
                CUTF8String input(reinterpret_cast<const uint8_t*>(path));
                picture.fromFileAtPath(&input);
                require(pictures.count(picture.getPicture()), "file output survives argument cleanup");
            }
        } else if (name == "bytes") {
            const uint8_t bytes[] = {1, 2, 3};
            picture.setBytes(bytes, sizeof(bytes));
            picture.setBytes(nullptr, 0);
        } else if (name == "copy" || name == "copy-empty") {
            std::vector<const char*> types = {""};
            if (name == "copy") types = {".png", "\xe6\x97\xa5", "\xf0\x9f\x98\x80", ""};
            for (const char* type : types) {
                expectedType = utf16(type);
                PA_Picture output = picture.createCopy(type);
                require(pictures.count(output), "owning conversion handoff survives clear");
                handoffs.push_back(output);
                require(pictures.count(picture.getPicture()), "independent original picture");
            }
        } else if (name == "gray") {
            PA_Picture output = picture.createGrayScale();
            require(pictures.count(output), "owning grayscale handoff survives clear");
            handoffs.push_back(output);
        } else if (name == "size") {
            unsigned width = 0, height = 0;
            picture.getSize(&width, &height);
            require(width == 17 && height == 23, "exact picture dimensions");
        } else if (name == "thumbnail") {
            PA_Picture output = picture.createThumbnail(17, 23);
            require(pictures.count(output), "owning thumbnail handoff survives clear");
            handoffs.push_back(output);
        } else {
            require(false, "unknown picture test case");
        }
        for (PA_Picture output : handoffs) {
            require(pictures.count(output), "owning handoff survives wrapper destruction");
            PA_DisposePicture(output);
        }
    }
    balanced(name.c_str());
}

void arrayCase()
{
    PA_Variable array = PA_CreateVariable(eVK_ArrayUnicode);
    PA_ResizeArray(&array, 4);
    const char* fixtures[] = {"", "ASCII", "\xe6\x97\xa5", "\xf0\x9f\x98\x80", ""};
    ARRAY_TEXT wrapper;
    for (const char* fixture : fixtures) {
        CUTF16String value = utf16(fixture);
        wrapper.appendUTF16String(&value);
    }
    BytePtr params[] = {reinterpret_cast<BytePtr>(&array)};
    wrapper.toParamAtIndex(params, 1);
    std::set<PA_Unichar*> owners;
    for (int i = 0; i < 5; ++i) {
        PA_Unistring borrowed = PA_GetStringInArray(array, i);
        require(text(borrowed) == utf16(fixtures[i]), "exact array content after transfer");
        if (borrowed.fString)
            require(owners.insert(borrowed.fString).second, "independent allocation per element");
    }
    ARRAY_TEXT copied;
    copied.fromParamAtIndex(params, 1);
    wrapper.toParamAtIndex(params, 1); // Replacement releases old owners.
    for (int i = 0; i < 5; ++i)
        require(text(PA_GetStringInArray(array, i)) == utf16(fixtures[i]),
                "replacement survives allocator churn");
    PA_ResizeArray(&array, 1);
    PA_ClearVariable(&array);
    CUTF16String independent;
    copied.copyUTF16StringAtIndex(&independent, 3);
    require(independent == utf16(fixtures[3]), "borrowed text copied before owner mutation");

    PA_Variable rejected = PA_CreateVariable(eVK_Longint);
    CUTF16String source = utf16("retained");
    PA_Unistring value = PA_CreateUnistring(const_cast<PA_Unichar*>(source.c_str()));
    PA_SetStringInArray(rejected, 0, &value);
    require(text(value) == source, "rejected type retains caller ownership");
    PA_DisposeUnistring(&value);
    array = PA_CreateVariable(eVK_ArrayUnicode);
    for (int index : {-1, 1}) {
        value = PA_CreateUnistring(const_cast<PA_Unichar*>(source.c_str()));
        PA_SetStringInArray(array, index, &value);
        require(text(value) == source, "rejected index retains caller ownership");
        PA_DisposeUnistring(&value);
    }
    PA_SetStringInArray(array, 0, nullptr);
    require(text(PA_GetStringInArray(array, 0)).empty(), "null descriptor leaves element intact");
    PA_Variable missing = {};
    missing.fType = eVK_ArrayUnicode;
    value = PA_CreateUnistring(const_cast<PA_Unichar*>(source.c_str()));
    PA_SetStringInArray(missing, 0, &value);
    require(text(value) == source, "null array data retains caller ownership");
    PA_DisposeUnistring(&value);
    PA_ClearVariable(&array);
    balanced("arrays");
}

void scalarCase()
{
    const PA_Unichar ascii[] = {'A', 'S', 'C', 'I', 'I'};
    const PA_Unichar bmp[] = {0x65e5};
    const PA_Unichar supplementary[] = {0xd83d, 0xde00};
    require(utf16("ASCII") == CUTF16String(ascii, 5), "exact ASCII fixture");
    require(utf16("\xe6\x97\xa5") == CUTF16String(bmp, 1), "exact BMP fixture");
    require(utf16("\xf0\x9f\x98\x80") == CUTF16String(supplementary, 2),
            "exact supplementary surrogate pair");
    require(utf16("").empty(), "exact empty fixture");
    for (const char* fixture : {"", "ASCII", "\xe6\x97\xa5", "\xf0\x9f\x98\x80"}) {
        CUTF16String expected = utf16(fixture);
        require(expected.size() == (std::strlen(fixture) == 4 ? 2 :
                std::strlen(fixture) == 3 ? 1 : std::strlen(fixture)), "fixture UTF-16 units");
        PA_Unistring source = PA_CreateUnistring(const_cast<PA_Unichar*>(expected.c_str()));
        C_TEXT wrapper;
        BytePtr params[] = {reinterpret_cast<BytePtr>(&source)};
        wrapper.fromParamAtIndex(params, 1);
        PA_DisposeUnistring(&source);
        wrapper.toParamAtIndex(params, 1);
        require(text(source) == expected, "scalar input copied before disposal");
        PA_Unistring output = {};
        PA_Unistring* result = &output;
        wrapper.setReturn(reinterpret_cast<sLONG_PTR*>(&result));
        require(text(output) == expected, "scalar return content setter");
        if (source.fString && output.fString)
            require(source.fString != output.fString, "independent scalar return allocation");
        PA_DisposeUnistring(&source);
        require(text(output) == expected, "return survives independent cleanup");
        PA_DisposeUnistring(&output);
    }
    balanced("scalars");
}
}

int main(int argc, char** argv)
{
    require(argc >= 2, "named test case required");
    gCall4D = engine;
    allocatedEmpty = argc < 3 || std::strcmp(argv[2], "null-empty") != 0;
    std::string name(argv[1]);
    @autoreleasepool {
        if (name == "arrays") arrayCase();
        else if (name == "scalars") scalarCase();
        else pictureCase(name);
    }
    std::printf("PASS %s (%s)\n", argv[1], allocatedEmpty ? "allocated-empty" : "null-empty");
}
