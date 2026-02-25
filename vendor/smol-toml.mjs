/* esm.sh - smol-toml@1.3.0 */
function R(e,n){let t=e.slice(0,n).split(/\r\n|\n|\r/g);return[t.length,t.pop().length+1]}function Z(e,n,t){let i=e.split(/\r\n|\n|\r/g),l="",r=(Math.log10(n+1)|0)+1;for(let o=n-1;o<=n+1;o++){let f=i[o-1];f&&(l+=o.toString().padEnd(r," "),l+=":  ",l+=f,l+=`
`,o===n&&(l+=" ".repeat(r+t+2),l+=`^
`))}return l}var a=class extends Error{line;column;codeblock;constructor(n,t){let[i,l]=R(t.toml,t.ptr),r=Z(t.toml,i,l);super(`Invalid TOML document: ${n}

${r}`,t),this.line=i,this.column=l,this.codeblock=r}};function m(e,n=0,t=e.length){let i=e.indexOf(`
`,n);return e[i-1]==="\r"&&i--,i<=t?i:-1}function h(e,n){for(let t=n;t<e.length;t++){let i=e[t];if(i===`
`)return t;if(i==="\r"&&e[t+1]===`
`)return t+1;if(i<" "&&i!=="	"||i==="\x7F")throw new a("control characters are not allowed in comments",{toml:e,ptr:n})}return e.length}function d(e,n,t,i){let l;for(;(l=e[n])===" "||l==="	"||!t&&(l===`
`||l==="\r"&&e[n+1]===`
`);)n++;return i||l!=="#"?n:d(e,h(e,n),t)}function T(e,n,t,i,l=!1){if(!i)return n=m(e,n),n<0?e.length:n;for(let r=n;r<e.length;r++){let o=e[r];if(o==="#")r=m(e,r);else{if(o===t)return r+1;if(o===i)return r;if(l&&(o===`
`||o==="\r"&&e[r+1]===`
`))return r}}throw new a("cannot find end of structure",{toml:e,ptr:n})}function y(e,n){let t=e[n],i=t===e[n+1]&&e[n+1]===e[n+2]?e.slice(n,n+3):t;n+=i.length-1;do n=e.indexOf(i,++n);while(n>-1&&t!=="'"&&e[n-1]==="\\"&&e[n-2]!=="\\");return n>-1&&(n+=i.length,i.length>1&&(e[n]===t&&n++,e[n]===t&&n++)),n}var v=/^(\d{4}-\d{2}-\d{2})?[T ]?(?:(\d{2}):\d{2}:\d{2}(?:\.\d+)?)?(Z|[-+]\d{2}:\d{2})?$/i,w=class e extends Date{#n=!1;#t=!1;#e=null;constructor(n){let t=!0,i=!0,l="Z";if(typeof n=="string"){let r=n.match(v);r?(r[1]||(t=!1,n=`0000-01-01T${n}`),i=!!r[2],r[2]&&+r[2]>23?n="":(l=r[3]||null,n=n.toUpperCase(),!l&&i&&(n+="Z"))):n=""}super(n),isNaN(this.getTime())||(this.#n=t,this.#t=i,this.#e=l)}isDateTime(){return this.#n&&this.#t}isLocal(){return!this.#n||!this.#t||!this.#e}isDate(){return this.#n&&!this.#t}isTime(){return this.#t&&!this.#n}isValid(){return this.#n||this.#t}toISOString(){let n=super.toISOString();if(this.isDate())return n.slice(0,10);if(this.isTime())return n.slice(11,23);if(this.#e===null)return n.slice(0,-1);if(this.#e==="Z")return n;let t=+this.#e.slice(1,3)*60+ +this.#e.slice(4,6);return t=this.#e[0]==="-"?t:-t,new Date(this.getTime()-t*6e4).toISOString().slice(0,-1)+this.#e}static wrapAsOffsetDateTime(n,t="Z"){let i=new e(n);return i.#e=t,i}static wrapAsLocalDateTime(n){let t=new e(n);return t.#e=null,t}static wrapAsLocalDate(n){let t=new e(n);return t.#t=!1,t.#e=null,t}static wrapAsLocalTime(n){let t=new e(n);return t.#n=!1,t.#e=null,t}};var z=/^((0x[0-9a-fA-F](_?[0-9a-fA-F])*)|(([+-]|0[ob])?\d(_?\d)*))$/,K=/^[+-]?\d(_?\d)*(\.\d(_?\d)*)?([eE][+-]?\d(_?\d)*)?$/,M=/^[+-]?0[0-9_]/,F=/^[0-9a-f]{4,8}$/i,k={b:"\b",t:"	",n:`
`,f:"\f",r:"\r",'"':'"',"\\":"\\"};function b(e,n=0,t=e.length){let i=e[n]==="'",l=e[n++]===e[n]&&e[n]===e[n+1];l&&(t-=2,e[n+=2]==="\r"&&n++,e[n]===`
`&&n++);let r=0,o,f="",u=n;for(;n<t-1;){let c=e[n++];if(c===`
`||c==="\r"&&e[n]===`
`){if(!l)throw new a("newlines are not allowed in strings",{toml:e,ptr:n-1})}else if(c<" "&&c!=="	"||c==="\x7F")throw new a("control characters are not allowed in strings",{toml:e,ptr:n-1});if(o){if(o=!1,c==="u"||c==="U"){let s=e.slice(n,n+=c==="u"?4:8);if(!F.test(s))throw new a("invalid unicode escape",{toml:e,ptr:r});try{f+=String.fromCodePoint(parseInt(s,16))}catch{throw new a("invalid unicode escape",{toml:e,ptr:r})}}else if(l&&(c===`
`||c===" "||c==="	"||c==="\r")){if(n=d(e,n-1,!0),e[n]!==`
`&&e[n]!=="\r")throw new a("invalid escape: only line-ending whitespace may be escaped",{toml:e,ptr:r});n=d(e,n)}else if(c in k)f+=k[c];else throw new a("unrecognized escape sequence",{toml:e,ptr:r});u=n}else!i&&c==="\\"&&(r=n-1,o=!0,f+=e.slice(u,r))}return f+e.slice(u,t-1)}function I(e,n,t){if(e==="true")return!0;if(e==="false")return!1;if(e==="-inf")return-1/0;if(e==="inf"||e==="+inf")return 1/0;if(e==="nan"||e==="+nan"||e==="-nan")return NaN;if(e==="-0")return 0;let i;if((i=z.test(e))||K.test(e)){if(M.test(e))throw new a("leading zeroes are not allowed",{toml:n,ptr:t});let r=+e.replace(/_/g,"");if(isNaN(r))throw new a("invalid number",{toml:n,ptr:t});if(i&&!Number.isSafeInteger(r))throw new a("integer value cannot be represented losslessly",{toml:n,ptr:t});return r}let l=new w(e);if(!l.isValid())throw new a("invalid value",{toml:n,ptr:t});return l}function G(e,n,t,i){let l=e.slice(n,t),r=l.indexOf("#");r>-1&&(h(e,r),l=l.slice(0,r));let o=l.trimEnd();if(!i){let f=l.indexOf(`
`,o.length);if(f>-1)throw new a("newlines are not allowed in inline tables",{toml:e,ptr:n+f})}return[o,r]}function g(e,n,t){let i=e[n];if(i==="["||i==="{"){let[o,f]=i==="["?N(e,n):$(e,n),u=T(e,f,",",t);if(t==="}"){let c=m(e,f,u);if(c>-1)throw new a("newlines are not allowed in inline tables",{toml:e,ptr:c})}return[o,u]}let l;if(i==='"'||i==="'"){l=y(e,n);let o=b(e,n,l);if(t){if(l=d(e,l,t!=="]"),e[l]&&e[l]!==","&&e[l]!==t&&e[l]!==`
`&&e[l]!=="\r")throw new a("unexpected character encountered",{toml:e,ptr:l});l+=+(e[l]===",")}return[o,l]}l=T(e,n,",",t);let r=G(e,n,l-+(e[l-1]===","),t==="]");if(!r[0])throw new a("incomplete key-value declaration: no value specified",{toml:e,ptr:n});return t&&r[1]>-1&&(l=d(e,n+r[1]),l+=+(e[l]===",")),[I(r[0],e,n),l]}var U=/^[a-zA-Z0-9-_]+[ \t]*$/;function x(e,n,t="="){let i=n-1,l=[],r=e.indexOf(t,n);if(r<0)throw new a("incomplete key-value: cannot find end of key",{toml:e,ptr:n});do{let o=e[n=++i];if(o!==" "&&o!=="	")if(o==='"'||o==="'"){if(o===e[n+1]&&o===e[n+2])throw new a("multiline strings are not allowed in keys",{toml:e,ptr:n});let f=y(e,n);if(f<0)throw new a("unfinished string encountered",{toml:e,ptr:n});i=e.indexOf(".",f);let u=e.slice(f,i<0||i>r?r:i),c=m(u);if(c>-1)throw new a("newlines are not allowed in keys",{toml:e,ptr:n+i+c});if(u.trimStart())throw new a("found extra tokens after the string part",{toml:e,ptr:f});if(r<f&&(r=e.indexOf(t,f),r<0))throw new a("incomplete key-value: cannot find end of key",{toml:e,ptr:n});l.push(b(e,n,f))}else{i=e.indexOf(".",n);let f=e.slice(n,i<0||i>r?r:i);if(!U.test(f))throw new a("only letter, numbers, dashes and underscores are allowed in keys",{toml:e,ptr:n});l.push(f.trimEnd())}}while(i+1&&i<r);return[l,d(e,r+1,!0,!0)]}function $(e,n){let t={},i=new Set,l,r=0;for(n++;(l=e[n++])!=="}"&&l;){if(l===`
`)throw new a("newlines are not allowed in inline tables",{toml:e,ptr:n-1});if(l==="#")throw new a("inline tables cannot contain comments",{toml:e,ptr:n-1});if(l===",")throw new a("expected key-value, found comma",{toml:e,ptr:n-1});if(l!==" "&&l!=="	"){let o,f=t,u=!1,[c,s]=x(e,n-1);for(let p=0;p<c.length;p++){if(p&&(f=u?f[o]:f[o]={}),o=c[p],(u=Object.hasOwn(f,o))&&(typeof f[o]!="object"||i.has(f[o])))throw new a("trying to redefine an already defined value",{toml:e,ptr:n});!u&&o==="__proto__"&&Object.defineProperty(f,o,{enumerable:!0,configurable:!0,writable:!0})}if(u)throw new a("trying to redefine an already defined value",{toml:e,ptr:n});let[_,C]=g(e,s,"}");i.add(_),f[o]=_,n=C,r=e[n-1]===","?n-1:0}}if(r)throw new a("trailing commas are not allowed in inline tables",{toml:e,ptr:r});if(!l)throw new a("unfinished table encountered",{toml:e,ptr:n});return[t,n]}function N(e,n){let t=[],i;for(n++;(i=e[n++])!=="]"&&i;){if(i===",")throw new a("expected value, found comma",{toml:e,ptr:n-1});if(i==="#")n=h(e,n);else if(i!==" "&&i!=="	"&&i!==`
`&&i!=="\r"){let l=g(e,n-1,"]");t.push(l[0]),n=l[1]}}if(!i)throw new a("unfinished array encountered",{toml:e,ptr:n});return[t,n]}function D(e,n,t,i){let l=n,r=t,o,f=!1,u;for(let c=0;c<e.length;c++){if(c){if(l=f?l[o]:l[o]={},r=(u=r[o]).c,i===0&&(u.t===1||u.t===2))return null;if(u.t===2){let s=l.length-1;l=l[s],r=r[s].c}}if(o=e[c],(f=Object.hasOwn(l,o))&&r[o]?.t===0&&r[o]?.d)return null;f||(o==="__proto__"&&(Object.defineProperty(l,o,{enumerable:!0,configurable:!0,writable:!0}),Object.defineProperty(r,o,{enumerable:!0,configurable:!0,writable:!0})),r[o]={t:c<e.length-1&&i===2?3:i,d:!1,i:0,c:{}})}if(u=r[o],u.t!==i&&!(i===1&&u.t===3)||(i===2&&(u.d||(u.d=!0,l[o]=[]),l[o].push(l={}),u.c[u.i++]=u={t:1,d:!1,i:0,c:{}}),u.d))return null;if(u.d=!0,i===1)l=f?l[o]:l[o]={};else if(i===0&&f)return null;return[o,l,u.c]}function V(e){let n={},t={},i=n,l=t;for(let r=d(e,0);r<e.length;){if(e[r]==="["){let o=e[++r]==="[",f=x(e,r+=+o,"]");if(o){if(e[f[1]-1]!=="]")throw new a("expected end of table declaration",{toml:e,ptr:f[1]-1});f[1]++}let u=D(f[0],n,t,o?2:1);if(!u)throw new a("trying to redefine an already defined table or value",{toml:e,ptr:r});l=u[2],i=u[1],r=f[1]}else{let o=x(e,r),f=D(o[0],i,l,0);if(!f)throw new a("trying to redefine an already defined table or value",{toml:e,ptr:r});let u=g(e,o[1]);f[1][f[0]]=u[0],r=u[1]}if(r=d(e,r,!0),e[r]&&e[r]!==`
`&&e[r]!=="\r")throw new a("each key-value declaration must be followed by an end-of-line",{toml:e,ptr:r});r=d(e,r)}return n}var L=/^[a-z0-9-_]+$/i;function E(e){let n=typeof e;if(n==="object"){if(Array.isArray(e))return"array";if(e instanceof Date)return"date"}return n}function X(e){for(let n=0;n<e.length;n++)if(E(e[n])!=="object")return!1;return e.length!=0}function O(e){return JSON.stringify(e).replace(/\x7f/g,"\\u007f")}function S(e,n=E(e)){if(n==="number")return isNaN(e)?"nan":e===1/0?"inf":e===-1/0?"-inf":e.toString();if(n==="bigint"||n==="boolean")return e.toString();if(n==="string")return O(e);if(n==="date"){if(isNaN(e.getTime()))throw new TypeError("cannot serialize invalid date");return e.toISOString()}if(n==="object")return B(e);if(n==="array")return Y(e)}function B(e){let n=Object.keys(e);if(n.length===0)return"{}";let t="{ ";for(let i=0;i<n.length;i++){let l=n[i];i&&(t+=", "),t+=L.test(l)?l:O(l),t+=" = ",t+=S(e[l])}return t+" }"}function Y(e){if(e.length===0)return"[]";let n="[ ";for(let t=0;t<e.length;t++){if(t&&(n+=", "),e[t]===null||e[t]===void 0)throw new TypeError("arrays cannot contain null or undefined values");n+=S(e[t])}return n+" ]"}function j(e,n){let t="";for(let i=0;i<e.length;i++)t+=`[[${n}]]
`,t+=A(e[i],n),t+=`

`;return t}function A(e,n=""){let t="",i="",l=Object.keys(e);for(let r=0;r<l.length;r++){let o=l[r];if(e[o]!==null&&e[o]!==void 0){let f=E(e[o]);if(f==="symbol"||f==="function")throw new TypeError(`cannot serialize values of type '${f}'`);let u=L.test(o)?o:O(o);if(f==="array"&&X(e[o]))i+=j(e[o],n?`${n}.${u}`:u);else if(f==="object"){let c=n?`${n}.${u}`:u;i+=`[${c}]
`,i+=A(e[o],c),i+=`

`}else t+=u,t+=" = ",t+=S(e[o],f),t+=`
`}}return`${t}
${i}`.trim()}function P(e){if(E(e)!=="object")throw new TypeError("stringify can only be called with an object");return A(e)}var Oe={parse:V,stringify:P,TomlDate:w,TomlError:a};export{w as TomlDate,a as TomlError,Oe as default,V as parse,P as stringify};
/*! Bundled license information:

smol-toml/dist/error.js:
smol-toml/dist/util.js:
smol-toml/dist/date.js:
smol-toml/dist/primitive.js:
smol-toml/dist/extract.js:
smol-toml/dist/struct.js:
smol-toml/dist/parse.js:
smol-toml/dist/stringify.js:
smol-toml/dist/index.js:
  (*!
   * Copyright (c) Squirrel Chat et al., All rights reserved.
   * SPDX-License-Identifier: BSD-3-Clause
   *
   * Redistribution and use in source and binary forms, with or without
   * modification, are permitted provided that the following conditions are met:
   *
   * 1. Redistributions of source code must retain the above copyright notice, this
   *    list of conditions and the following disclaimer.
   * 2. Redistributions in binary form must reproduce the above copyright notice,
   *    this list of conditions and the following disclaimer in the
   *    documentation and/or other materials provided with the distribution.
   * 3. Neither the name of the copyright holder nor the names of its contributors
   *    may be used to endorse or promote products derived from this software without
   *    specific prior written permission.
   *
   * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
   * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
   * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
   * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
   * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
   * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
   * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
   * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
   * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
   * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
   *)
*/
//# sourceMappingURL=smol-toml.mjs.map