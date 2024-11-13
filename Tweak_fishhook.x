#import "fishhook.h"
#include <OpenGLES/ES3/gl.h>
#include <CoreVideo/CVPixelBuffer.h>
#import <Foundation/Foundation.h> 

extern void flog(NSString *format, ...);

void saveRGBAData(const void *data, int width, int height) {

}

void getShaderInfo(GLuint shaderID);

static void (*old_glShaderSource) (GLuint shader, GLsizei count, const GLchar* const *string, const GLint* length);

void my_glShaderSource (GLuint shader, GLsizei count, const GLchar* const *string, const GLint* length) {
    for (int i = 0; i < count; ++i) {
        flog(@"glShaderSource shader:%d string:\n%s", shader, string[i]);
    }
    old_glShaderSource(shader, count, string, length);
}

static GLuint (*old_glCreateProgram) (void);

GLuint my_glCreateProgram (void) {
    GLuint pid = old_glCreateProgram();
    flog(@"glCreateProgram:%d", pid);
    return pid;
}

static void (*old_glDeleteProgram) (GLuint program);

void my_glDeleteProgram (GLuint program) {
    flog(@"glDeleteProgram:%d", program);
    old_glDeleteProgram(program);
}

static void (*old_glGenTextures) (GLsizei n, GLuint* textures);

void my_glGenTextures (GLsizei n, GLuint* textures) {
    for (int i = 0; i < n; ++i) {
        flog(@"glGenTextures:%d", textures[i]);
    }
    old_glGenTextures(n, textures);
}

static void (*old_glBindTexture) (GLenum target, GLuint texture);

void my_glBindTexture (GLenum target, GLuint texture) {
    flog(@"glBindTexture target:%d texture:%d", target, texture);
    old_glBindTexture(target, texture);
}

static void (*old_glTexImage2D)(GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const void *pixels);

void my_glTexImage2D(GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const void *pixels) {
    flog(@"glTexImage2D target:%d level:%d internalformat:%d width:%d height:%d border:%d format:%d type:%d pixels:%p", target, level, internalformat, width, height, border, format, type, pixels);
    if (format == 6408) {
        saveRGBAData(pixels, width, height);
    }
    old_glTexImage2D(target, level, internalformat, width, height, border, format, type, pixels);
}

static void (*old_glTexSubImage2D)(GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, const void *pixels);

void my_glTexSubImage2D(GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, const void *pixels) {
    flog(@"glTexSubImage2D target:%d level:%d xoffset:%d yoffset:%d width:%d height:%d format:%d type:%d pixels:%p", target, level, xoffset, yoffset, width, height, format, type, pixels);
    old_glTexSubImage2D(target, level, xoffset, yoffset, width, height, format, type, pixels);
}

static void (*old_glViewport)(GLint x, GLint y, GLsizei width, GLsizei height);

void my_glViewport(GLint x, GLint y, GLsizei width, GLsizei height) {
    flog(@"glViewport x:%d y:%d width:%d height:%d", x, y, width, height);
    old_glViewport(x, y, width, height);
}

static void (*old_glBindFramebuffer)(GLenum target, GLuint framebuffer);

void my_glBindFramebuffer(GLenum target, GLuint framebuffer) {
    flog(@"glBindFramebuffer target:%d framebuffer:%d", target, framebuffer);
    old_glBindFramebuffer(target, framebuffer);
}

static void (*old_glUseProgram)(GLuint program);
static int _currentProgram = 0;
void my_glUseProgram(GLuint program) {
    flog(@"glUseProgram program:%d", program);
    _currentProgram = program;
    old_glUseProgram(program);
    
    // 可在console查看日志
    return;
    
    if (program == 0) {
        flog(@"program 0");
        return;
    }
    
    int MAX_SHADER_ATTACHMENTS = 50;
    
    // 创建一个存储着色器对象句柄的数组
    GLuint shaderHandles[MAX_SHADER_ATTACHMENTS];
    GLsizei shaderCount;

    // 获取附加到程序对象的着色器列表
    glGetAttachedShaders(program, MAX_SHADER_ATTACHMENTS, &shaderCount, shaderHandles);

    // 输出附加的着色器数量和它们的句柄
    flog(@"program: %d Attached Shaders: %d", program, shaderCount);
    for (int i = 0; i < shaderCount; i++) {
        flog(@"Shader %d: %u", i, shaderHandles[i]);
        
        getShaderInfo(shaderHandles[i]);
    }
    
}

void getShaderInfo(GLuint shaderID) {
    // 查询着色器对象类型
    GLint shaderType;
    glGetShaderiv(shaderID, GL_SHADER_TYPE, &shaderType);

    switch (shaderType) {
        case GL_VERTEX_SHADER:
            flog(@"Shader is a vertex shader.");
            break;
        case GL_FRAGMENT_SHADER:
            flog(@"Shader is a fragment shader.");
            break;
        default:
            flog(@"Shader type is unknown.");
            return;
    }

    // 查询源代码长度
    GLint sourceLength;
    glGetShaderiv(shaderID, GL_SHADER_SOURCE_LENGTH, &sourceLength);

    // 创建足够大的缓冲区来存储源代码
    GLchar *shaderSource = (GLchar *)malloc(sourceLength);

    // 获取着色器对象的源代码
    glGetShaderSource(shaderID, sourceLength, NULL, shaderSource);

    // 打印源代码
    flog(@"Shader Source Code:\n%s\n", shaderSource);
    
    printf("Shader Source Code:\n%s\n", shaderSource);

    // 释放缓冲区
    free(shaderSource);
}

static void (*old_glActiveTexture)(GLenum texture);

void my_glActiveTexture(GLenum texture) {
    flog(@"glActiveTexture texture:%d", texture);
    old_glActiveTexture(texture);
}

static void (*old_glDrawArrays)(GLenum mode, GLint first, GLsizei count);

void readData() {
    return;
    
    int res[4];
    glGetIntegerv(GL_VIEWPORT, res);
    int width = res[2], height = res[3];
    GLubyte *imageData = (GLubyte *)malloc(width * height * 4);
    
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    flog(@"readData");
    saveRGBAData(imageData, width, height);
    free(imageData);
}

void my_glDrawArrays(GLenum mode, GLint first, GLsizei count) {
    flog(@"glDrawArrays mode:%d first:%d count:%d", mode, first, count);
    old_glDrawArrays(mode, first, count);

    if (_currentProgram == 2) {
        readData();
    }
}

static void (*old_glDrawElements)(GLenum mode, GLsizei count, GLenum type, const void *indices);

void my_glDrawElements(GLenum mode, GLsizei count, GLenum type, const void *indices) {
    flog(@"glDrawElements mode:%d count:%d type:%d indices:%p", mode, count, type, indices);
    old_glDrawElements(mode, count, type, indices);
    
    if (_currentProgram == 2) {
        readData();
    }
}

static void (*old_glGenFramebuffers)(GLsizei n, GLuint *framebuffers);

void my_glGenFramebuffers(GLsizei n, GLuint *framebuffers) {
    flog(@"glGenFramebuffers n:%d framebuffers:%p", n, framebuffers);
    old_glGenFramebuffers(n, framebuffers);
}

static void (*old_glFramebufferTexture2D)(GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level);

void my_glFramebufferTexture2D(GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level) {
    flog(@"glFramebufferTexture2D target:%d attachment:%d textarget:%d texture:%d level:%d", target, attachment, textarget, texture, level);
    old_glFramebufferTexture2D(target, attachment, textarget, texture, level);
}

static void (*old_glUniform1f)(GLint location, GLfloat v0);
static void (*old_glUniform1fv)(GLint location, GLsizei count, const GLfloat *value);
static void (*old_glUniform1i)(GLint location, GLint v0);
static void (*old_glUniform1iv)(GLint location, GLsizei count, const GLint *value);
static void (*old_glUniform2f)(GLint location, GLfloat v0, GLfloat v1);
static void (*old_glUniform2fv)(GLint location, GLsizei count, const GLfloat *value);
static void (*old_glUniform2i)(GLint location, GLint v0, GLint v1);
static void (*old_glUniform2iv)(GLint location, GLsizei count, const GLint *value);
static void (*old_glUniform3f)(GLint location, GLfloat v0, GLfloat v1, GLfloat v2);
static void (*old_glUniform3fv)(GLint location, GLsizei count, const GLfloat *value);
static void (*old_glUniform3i)(GLint location, GLint v0, GLint v1, GLint v2);
static void (*old_glUniform3iv)(GLint location, GLsizei count, const GLint *value);
static void (*old_glUniform4f)(GLint location, GLfloat v0, GLfloat v1, GLfloat v2, GLfloat v3);
static void (*old_glUniform4fv)(GLint location, GLsizei count, const GLfloat *value);
static void (*old_glUniform4i)(GLint location, GLint v0, GLint v1, GLint v2, GLint v3);
static void (*old_glUniform4iv)(GLint location, GLsizei count, const GLint *value);

void my_glUniform1f(GLint location, GLfloat v0) {
    flog(@"glUniform1f location:%d v0:%f", location, v0);
    old_glUniform1f(location, v0);
}

void my_glUniform1fv(GLint location, GLsizei count, const GLfloat *value) {
    for (int i = 0; i < count; ++i) {
        flog(@"glUniform1fv location:%d value:%f", location, value[i]);
    }
    old_glUniform1fv(location, count, value);
}

void my_glUniform1i(GLint location, GLint v0) {
    flog(@"glUniform1i location:%d v0:%d", location, v0);
    old_glUniform1i(location, v0);
}

void my_glUniform1iv(GLint location, GLsizei count, const GLint *value) {
    for (int i = 0; i < count; ++i) {
        flog(@"glUniform1iv location:%d value:%f", location, value[i]);
    }
    old_glUniform1iv(location, count, value);
}

void my_glUniform2f(GLint location, GLfloat v0, GLfloat v1) {
    flog(@"glUniform2f location:%d v0:%f v1:%f", location, v0, v1);
    old_glUniform2f(location, v0, v1);
}

void my_glUniform2fv(GLint location, GLsizei count, const GLfloat *value) {
    for (int i = 0; i < count; ++i) {
        flog(@"glUniform2fv location:%d value:%f", location, value[i]);
    }
    old_glUniform2fv(location, count, value);
}

void my_glUniform2i(GLint location, GLint v0, GLint v1) {
    flog(@"glUniform2i location:%d v0:%d v1:%d", location, v0, v1);
    old_glUniform2i(location, v0, v1);
}

void my_glUniform2iv(GLint location, GLsizei count, const GLint *value) {
    for (int i = 0; i < count; ++i) {
        flog(@"glUniform2iv location:%d value:%f", location, value[i]);
    }
    old_glUniform2iv(location, count, value);
}

void my_glUniform3f(GLint location, GLfloat v0, GLfloat v1, GLfloat v2) {
    flog(@"glUniform3f location:%d v0:%f v1:%f v2:%f", location, v0, v1, v2);
    old_glUniform3f(location, v0, v1, v2);
}

void my_glUniform3fv(GLint location, GLsizei count, const GLfloat *value) {
    for (int i = 0; i < count; ++i) {
        flog(@"glUniform3fv location:%d value:%f", location, value[i]);
    }
    old_glUniform3fv(location, count, value);
}

void my_glUniform3i(GLint location, GLint v0, GLint v1, GLint v2) {
    flog(@"glUniform3i location:%d v0:%d v1:%d v2:%d", location, v0, v1, v2);
    old_glUniform3i(location, v0, v1, v2);
}

void my_glUniform3iv(GLint location, GLsizei count, const GLint *value) {
    for (int i = 0; i < count; ++i) {
        flog(@"glUniform3iv location:%d value:%f", location, value[i]);
    }
    old_glUniform3iv(location, count, value);
}

void my_glUniform4f(GLint location, GLfloat v0, GLfloat v1, GLfloat v2, GLfloat v3) {
    flog(@"glUniform4f location:%d v0:%f v1:%f v2:%f v3:%f", location, v0, v1, v2, v3);
    old_glUniform4f(location, v0, v1, v2, v3);
}

void my_glUniform4fv(GLint location, GLsizei count, const GLfloat *value) {
    for (int i = 0; i < count; ++i) {
        flog(@"glUniform4fv location:%d value:%f", location, value[i]);
    }
    old_glUniform4fv(location, count, value);
}

void my_glUniform4i(GLint location, GLint v0, GLint v1, GLint v2, GLint v3) {
    flog(@"glUniform4i location:%d v0:%d v1:%d v2:%d v3:%d", location, v0, v1, v2, v3);
    old_glUniform4i(location, v0, v1, v2, v3);
}

void my_glUniform4iv(GLint location, GLsizei count, const GLint *value) {
    for (int i = 0; i < count; ++i) {
        flog(@"glUniform4iv location:%d value:%f", location, value[i]);
    }
    old_glUniform4iv(location, count, value);
}

void (*old_glFinish)();

void my_glFinish() {
    flog(@"glFinish");
    old_glFinish();
}

GLsync (*old_glFenceSync)(GLenum condition, GLbitfield flags);

GLsync my_glFenceSync(GLenum condition, GLbitfield flags) {
    flog(@"glFenceSync");
    return old_glFenceSync(condition, flags);
}

static void (*old_glReadPixels)(GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, void *);

static double _readPixelsTs = 0;

void my_glReadPixels(GLint x, GLint y, GLsizei width, GLsizei height, GLenum format, GLenum type, void * pixels) {
    flog(@"glReadPixels x:%d y:%d width:%d height:%d format:%d type:%d pixels:%p", x, y, width, height, format, type, pixels);
    NSTimeInterval before = [[NSDate date] timeIntervalSince1970];
    old_glReadPixels(x, y, width, height, format, type, pixels);
    NSTimeInterval after = [[NSDate date] timeIntervalSince1970];
//    _readPixelsTs = after;
//    if (format == 6408) {
//        saveRGBAData(pixels, width, height);
//    }
}

static void (*old_glBufferData)(GLenum target, GLsizeiptr size, const GLvoid *data, GLenum usage);

void my_glBufferData(GLenum target, GLsizeiptr size, const GLvoid *data, GLenum usage) {
    flog(@"glBufferData target:%d size:%lld data:%p usage:%d", target, size, data, usage);
//    if (size == 3582) {
//        NSTimeInterval ts = [[NSDate date] timeIntervalSince1970];
//        printf("glBufferData target:%d size:%lld data:%p usage:%d duration:%f\n", target, size, data, usage, (ts - _readPixelsTs) * 1000);
//    }
//    if (size == 3582) {
//        void *dstData = malloc(size);
//        memcpy(dstData, data, size);
//        float *floatPtr = data;
//        for (int i = 0; i < size / 4; ++i) {
//            printf("---- - %f\n", floatPtr[i]);
//        }
//        saveData(dstData, size);
//        free(dstData);
//    }
    
    old_glBufferData(target, size, data, usage);
}

static void (*old_glBufferSubData)(GLenum target, GLintptr offset, GLsizeiptr size, const GLvoid *data);

void my_glBufferSubData(GLenum target, GLintptr offset, GLsizeiptr size, const GLvoid *data) {
    flog(@"glBufferSubData target:%d offset:%ld size:%ld data:%p", target, (long)offset, (long)size, data);
//    float *floatPtr = data;
//    for (int i = 0; i < size / 4; ++i) {
//        printf("---- - %f\n", floatPtr[i]);
//    }
    old_glBufferSubData(target, offset, size, data);
}

static void (*old_glVertexAttribPointer)(GLuint indx, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const GLvoid* ptr);

void my_glVertexAttribPointer(GLuint indx, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const GLvoid* ptr) {
    flog(@"glVertexAttribPointer indx:%d size:%d type:%d normalized:%d stride:%d ptr:%p", indx, size, type, normalized, stride, ptr);
    old_glVertexAttribPointer(indx, size, type, normalized, stride, ptr);
}

static bool isLocked = false;
static NSTimeInterval _ts = 0;

CVReturn (*old_CVPixelBufferLockBaseAddress)(CVPixelBufferRef pixelBuffer, CVPixelBufferLockFlags lockFlags);

CVReturn my_CVPixelBufferLockBaseAddress(CVPixelBufferRef pixelBuffer, CVPixelBufferLockFlags lockFlags) {
    flog(@"CVPixelBufferLockBaseAddress");
    isLocked = true;
//    NSTimeInterval current = [[NSDate date] timeIntervalSince1970];
//    if (current - _ts > 1) {
//        savePixelBuffer(pixelBuffer);
//        _ts = current;
//    }
    return old_CVPixelBufferLockBaseAddress(pixelBuffer, lockFlags);
}

CVReturn (*old_CVPixelBufferUnlockBaseAddress)(CVPixelBufferRef pixelBuffer, CVPixelBufferLockFlags unlockFlags);

CVReturn my_CVPixelBufferUnlockBaseAddress(CVPixelBufferRef pixelBuffer, CVPixelBufferLockFlags unlockFlags) {
    flog(@"CVPixelBufferUnlockBaseAddress");
    isLocked = false;
    CVReturn res = old_CVPixelBufferUnlockBaseAddress(pixelBuffer, unlockFlags);
//    savePixelBuffer(pixelBuffer);
    return res;
}

// void *(*old_memcpy)(void * restrict dst, const void * restrict src, size_t n);

// void *my_memcpy(void * restrict dst, const void * restrict src, size_t n) {
//     if (isLocked) {
//         printf("memcpy size:%d\n", n);
//     }
//     return old_memcpy(dst, src, n);
// }

__attribute__((constructor))
static void initialize_tweak_fishhook() {
    flog(@"Tweaked fishhook");
    rebind_symbols((struct rebinding[1]){{"glShaderSource", my_glShaderSource, (void *)&old_glShaderSource}}, 1);
    rebind_symbols((struct rebinding[1]){{"glCreateProgram", my_glCreateProgram, (void *)&old_glCreateProgram}}, 1);
    rebind_symbols((struct rebinding[1]){{"glDeleteProgram", my_glDeleteProgram, (void *)&old_glDeleteProgram}}, 1);
    rebind_symbols((struct rebinding[1]){{"glBindTexture", my_glBindTexture, (void *)&old_glBindTexture}}, 1);
    rebind_symbols((struct rebinding[1]){{"glTexImage2D", my_glTexImage2D, (void*) &old_glTexImage2D}}, 1);
    rebind_symbols((struct rebinding[1]){{"glTexSubImage2D", my_glTexSubImage2D, (void*) &old_glTexSubImage2D}}, 1);
    rebind_symbols((struct rebinding[1]){{"glFenceSync", my_glFenceSync, (void*)&old_glFenceSync}}, 1);
    rebind_symbols((struct rebinding[1]){{"glFinish", my_glFinish, (void*)&old_glFinish}}, 1);
    rebind_symbols((struct rebinding[1]){{"glReadPixels", my_glReadPixels, (void*)&old_glReadPixels}}, 1);
    rebind_symbols((struct rebinding[1]){{"glBufferData", my_glBufferData, (void*)&old_glBufferData}}, 1);
    rebind_symbols((struct rebinding[1]){{"glVertexAttribPointer", my_glVertexAttribPointer, (void*)&old_glVertexAttribPointer}}, 1);
    rebind_symbols((struct rebinding[1]){{"glBufferSubData", my_glBufferSubData, (void*)&old_glBufferSubData}}, 1);
    rebind_symbols((struct rebinding[1]){{"glViewport", my_glViewport, (void*) &old_glViewport}}, 1);
    rebind_symbols((struct rebinding[1]){{"glBindFramebuffer", my_glBindFramebuffer, (void*) &old_glBindFramebuffer}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUseProgram", my_glUseProgram, (void*) &old_glUseProgram}}, 1);
    rebind_symbols((struct rebinding[1]){{"glActiveTexture", my_glActiveTexture, (void*) &old_glActiveTexture}}, 1);
    rebind_symbols((struct rebinding[1]){{"glDrawArrays", my_glDrawArrays, (void*) &old_glDrawArrays}}, 1);
    rebind_symbols((struct rebinding[1]){{"glDrawElements", my_glDrawElements, (void*) &old_glDrawElements}}, 1);
    rebind_symbols((struct rebinding[1]){{"glGenFramebuffers", my_glGenFramebuffers, (void*) &old_glGenFramebuffers}}, 1);
    rebind_symbols((struct rebinding[1]){{"glFramebufferTexture2D", my_glFramebufferTexture2D, (void*) &old_glFramebufferTexture2D}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform1f", my_glUniform1f, (void*)&old_glUniform1f}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform1fv", my_glUniform1fv, (void*)&old_glUniform1fv}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform1i", my_glUniform1i, (void*)&old_glUniform1i}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform1iv", my_glUniform1iv, (void*)&old_glUniform1iv}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform2f", my_glUniform2f, (void*)&old_glUniform2f}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform2fv", my_glUniform2fv, (void*)&old_glUniform2fv}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform2i", my_glUniform2i, (void*)&old_glUniform2i}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform2iv", my_glUniform2iv, (void*)&old_glUniform2iv}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform3f", my_glUniform3f, (void*)&old_glUniform3f}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform3fv", my_glUniform3fv, (void*)&old_glUniform3fv}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform3i", my_glUniform3i, (void*)&old_glUniform3i}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform3iv", my_glUniform3iv, (void*)&old_glUniform3iv}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform4f", my_glUniform4f, (void*)&old_glUniform4f}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform4fv", my_glUniform4fv, (void*)&old_glUniform4fv}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform4i", my_glUniform4i, (void*)&old_glUniform4i}}, 1);
    rebind_symbols((struct rebinding[1]){{"glUniform4iv", my_glUniform4iv, (void*)&old_glUniform4iv}}, 1);
    rebind_symbols((struct rebinding[1]){{"CVPixelBufferLockBaseAddress", my_CVPixelBufferLockBaseAddress, (void*)&old_CVPixelBufferLockBaseAddress}}, 1);
    rebind_symbols((struct rebinding[1]){{"CVPixelBufferUnlockBaseAddress", my_CVPixelBufferUnlockBaseAddress, (void*)&old_CVPixelBufferUnlockBaseAddress}}, 1);
//    rebind_symbols((struct rebinding[1]){{"memcpy", my_memcpy, (void*)&old_memcpy}}, 1);
}
