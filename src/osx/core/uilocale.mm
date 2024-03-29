///////////////////////////////////////////////////////////////////////////////
// Name:        src/osx/core/uilocale.mm
// Purpose:     wxUILocale implementation for macOS
// Author:      Vadim Zeitlin
// Created:     2021-08-01
// Copyright:   (c) 2021 Vadim Zeitlin <vadim@wxwidgets.org>
// Licence:     wxWindows licence
///////////////////////////////////////////////////////////////////////////////

// ============================================================================
// declarations
// ============================================================================

// ----------------------------------------------------------------------------
// headers
// ----------------------------------------------------------------------------

// for compilers that support precompilation, includes "wx.h".
#include "wx/wxprec.h"

#if wxUSE_INTL

#include "wx/uilocale.h"
#include "wx/private/uilocale.h"

#include "wx/osx/core/cfref.h"
#include "wx/osx/core/cfstring.h"

#import <Foundation/NSString.h>
#import <Foundation/NSLocale.h>

extern wxString
wxGetInfoFromCFLocale(CFLocaleRef cfloc, wxLocaleInfo index, wxLocaleCategory cat);

// ----------------------------------------------------------------------------
// wxLocaleIdent::GetName() implementation using Foundation
// ----------------------------------------------------------------------------

wxString wxLocaleIdent::GetName() const
{
    // Construct name in right format:
    // MacOS: <language>-<script>_<REGION>

    wxString name;
    if ( !m_language.empty() )
    {
        name << m_language;

        if ( !m_script.empty() )
        {
            name << "-" << m_script;
        }

        if ( !m_region.empty() )
        {
            name << "_" << m_region;
        }
    }

    return name;
}

namespace
{

// ----------------------------------------------------------------------------
// wxUILocale implementation using Core Foundation
// ----------------------------------------------------------------------------

class wxUILocaleImplCF : public wxUILocaleImpl
{
public:
    explicit wxUILocaleImplCF(NSLocale* nsloc)
        : m_nsloc([nsloc retain])
    {
    }

    ~wxUILocaleImplCF() wxOVERRIDE
    {
        [m_nsloc release];
    }

    static wxUILocaleImplCF* Create(const wxLocaleIdent& locId)
    {
        // Surprisingly, localeWithLocaleIdentifier: always succeeds, even for
        // completely invalid strings, so we need to check if the name is
        // actually in the list of the supported locales ourselves.
        static wxCFRef<CFArrayRef>
            all((CFArrayRef)[[NSLocale availableLocaleIdentifiers] retain]);

        wxCFStringRef cfName(locId.GetName());
        if ( ![(NSArray*)all.get() containsObject: cfName.AsNSString()] )
            return NULL;

        auto nsloc = [NSLocale localeWithLocaleIdentifier: cfName.AsNSString()];
        if ( !nsloc )
            return NULL;

        return new wxUILocaleImplCF(nsloc);
    }

    void Use() wxOVERRIDE;
    wxString GetName() const wxOVERRIDE;
    wxString GetInfo(wxLocaleInfo index, wxLocaleCategory cat) const wxOVERRIDE;
    int CompareStrings(const wxString& lhs, const wxString& rhs,
                       int flags) const wxOVERRIDE;

private:
    NSLocale* const m_nsloc;

    wxDECLARE_NO_COPY_CLASS(wxUILocaleImplCF);
};

} // anonymous namespace

// ============================================================================
// implementation
// ============================================================================

void
wxUILocaleImplCF::Use()
{
    // There is no way to start using a locale other than default, so there is
    // nothing to do here.
}

wxString
wxUILocaleImplCF::GetName() const
{
    return wxCFStringRef::AsString([m_nsloc localeIdentifier]);
}

wxString
wxUILocaleImplCF::GetInfo(wxLocaleInfo index, wxLocaleCategory cat) const
{
    return wxGetInfoFromCFLocale((CFLocaleRef)m_nsloc, index, cat);
}

/* static */
wxUILocaleImpl* wxUILocaleImpl::CreateStdC()
{
    return wxUILocaleImplCF::Create(wxLocaleIdent().Language("C"));
}

/* static */
wxUILocaleImpl* wxUILocaleImpl::CreateUserDefault()
{
    return new wxUILocaleImplCF([NSLocale currentLocale]);
}

/* static */
wxUILocaleImpl* wxUILocaleImpl::CreateForLocale(const wxLocaleIdent& locId)
{
    return wxUILocaleImplCF::Create(locId);
}

int
wxUILocaleImplCF::CompareStrings(const wxString& lhs, const wxString& rhs,
                                 int flags) const
{
    const wxCFStringRef cfstr(lhs);
    auto ns_lhs = cfstr.AsNSString();

    NSInteger options = 0;
    if ( flags & wxCompare_CaseInsensitive )
        options |= NSCaseInsensitiveSearch;

    NSComparisonResult ret = [ns_lhs compare:wxCFStringRef(rhs).AsNSString()
                                     options:options
                                     range:(NSRange){0, [ns_lhs length]}
                                     locale:m_nsloc];

    switch (ret)
    {
        case NSOrderedAscending:
            return -1;
        case NSOrderedSame:
            return 0;
        case NSOrderedDescending:
            return 1;
    }

    return 0;
}

#endif // wxUSE_INTL
