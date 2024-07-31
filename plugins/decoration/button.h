#ifndef BUTTON_H
#define BUTTON_H

#include <memory>
#include <KDecoration2/DecorationButton>

class Button : public KDecoration2::DecorationButton
{
public:
    explicit Button(KDecoration2::DecorationButtonType type, const QPointer<KDecoration2::Decoration> &decoration, QObject *parent = nullptr);

    static DecorationButton *create(KDecoration2::DecorationButtonType type, KDecoration2::Decoration *decoration, QObject *parent);

protected:
    virtual void paint(QPainter *painter, const QRect &repaintRegion) override;
};

#endif // BUTTON_H